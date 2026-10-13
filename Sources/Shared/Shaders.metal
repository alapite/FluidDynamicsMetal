//
//  Shaders.metal
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 02/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 textureCoorinates [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoorinates;
};

//Render to screen
vertex VertexOut vertexShader(constant VertexIn* vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]]) {

    VertexIn vertexData = vertexArray[vid];
    VertexOut vertexDataOut;
    vertexDataOut.position = float4(vertexData.position.x, vertexData.position.y, 0.0, 1.0);
    vertexDataOut.textureCoorinates = vertexData.textureCoorinates.xy;
    return vertexDataOut;
}

fragment half4 visualizeScalar(VertexOut fragmentIn [[stage_in]], texture2d<float, access::sample> tex2d [[texture(0)]]) {
    constexpr sampler sampler2d(filter::nearest);

    half4 color = half4(tex2d.sample(sampler2d, fragmentIn.textureCoorinates));

    return half4(half3(0.0, 0.06, 0.19) * abs(color.xxx), 1.0);
}

fragment half4 visualizeVector(VertexOut fragmentIn [[stage_in]], texture2d<float, access::sample> tex2d [[texture(0)]]) {
    constexpr sampler sampler2d(filter::nearest);

    half4 color = half4(tex2d.sample(sampler2d, fragmentIn.textureCoorinates));

    return half4(half4(0.5) + 0.5 * color);
}

// Preserve both RG16F channels over the entire normalized field on resize.
fragment half2 resampleField(VertexOut fragmentIn [[stage_in]],
                             texture2d<float, access::sample> oldField [[texture(0)]],
                             constant float2 &velocityScale [[buffer(0)]]) {
    constexpr sampler clampedSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    return half2(oldField.sample(clampedSampler, fragmentIn.textureCoorinates).xy * velocityScale);
}

//Fluid Dynamics Render Encoder

// GPU ABI: matches StaticData in SimulationTypes.swift. Offsets: 0, 80, 160, 168,
// 176, 184, 192; total size 208, alignment 16. See RendererContactTests.
struct BufferData {
    float2 positions[10];
    float2 impulses[10];

    float2 impulseScalar;
    float2 offsets;

    float2 screenSize;

    float inkRadius;
    float4 tuning;
};

inline float2 bilerpFrag(sampler textureSampler, texture2d<float> texture, float2 p, float2 screenSize) {
    float4 ij; // i0, j0, i1, j1
    ij.xy = floor(p - 0.5) + 0.5;
    ij.zw = ij.xy + 1.0;

    float4 uv = ij / screenSize.xyxy;
    float2 d11 = texture.sample(textureSampler, uv.xy).xy;
    float2 d21 = texture.sample(textureSampler, uv.zy).xy;
    float2 d12 = texture.sample(textureSampler, uv.xw).xy;
    float2 d22 = texture.sample(textureSampler, uv.zw).xy;

    float2 a = p - ij.xy;

    return mix(mix(d11, d21, a.x), mix(d12, d22, a.x), a.y);
}

inline half gaussSplat(half2 p, half r)
{
    return exp(-dot(p, p) / r);
}

fragment half2 applyForceVector(VertexOut fragmentIn [[stage_in]], texture2d<float, access::sample> input [[texture(0)]], constant BufferData &bufferData [[buffer(0)]]) {
    constexpr sampler fluid_sampler(filter::nearest);

    half2 screenSize = half2(bufferData.screenSize);
    float radius = bufferData.inkRadius;

    half2 color = half2(input.sample(fluid_sampler, fragmentIn.textureCoorinates).xy);
    half2 final = color;

    for (int i=0; i<10; ++i) {
        half2 impulse = half2(bufferData.impulses[i]);
        half2 location = half2(bufferData.positions[i]);

        if (location.x == location.y && location.x == 0) {
            continue;
        }

        half2 coords = location - half2(fragmentIn.textureCoorinates).xy * screenSize;
        half2 splat = impulse * gaussSplat(coords, radius);

        final = final + splat;
    }
    return final;
}

fragment half2 applyForceScalar(VertexOut fragmentIn [[stage_in]], texture2d<float, access::sample> input [[texture(0)]], constant BufferData &bufferData [[buffer(0)]]) {
    constexpr sampler fluid_sampler(filter::nearest);

    half2 impulseScalar = half2(bufferData.impulseScalar);
    half2 screenSize = half2(bufferData.screenSize);
    float radius = bufferData.inkRadius;

    half2 color = half2(input.sample(fluid_sampler, fragmentIn.textureCoorinates).xy);
    half2 final = color;

    for (int i=0; i<10; ++i) {
        half2 location = half2(bufferData.positions[i]);

        if (location.x == location.y && location.x == 0) {
            continue;
        }

        half2 coords = location - half2(fragmentIn.textureCoorinates).xy * screenSize;
        half2 splat = impulseScalar * gaussSplat(coords, radius);

        final = final + splat;
    }
    return final;
}

inline half2 advectField(float2 coordinates, texture2d<float> velocity, texture2d<float> advected,
                         constant BufferData &data, float retention) {
    constexpr sampler fluid_sampler(filter::nearest);
    float2 uv = coordinates * data.screenSize - velocity.sample(fluid_sampler, coordinates).xy;
    return half(retention) * half2(bilerpFrag(fluid_sampler, advected, uv, data.screenSize));
}
fragment half2 advect(VertexOut in [[stage_in]], texture2d<float> velocity [[texture(0)]],
                      texture2d<float> source [[texture(1)]], constant BufferData &data [[buffer(0)]]) {
    return advectField(in.textureCoorinates, velocity, source, data, data.tuning.x);
}
fragment half2 advectVelocity(VertexOut in [[stage_in]], texture2d<float> velocity [[texture(0)]],
                      texture2d<float> source [[texture(1)]], constant BufferData &data [[buffer(0)]]) {
    return advectField(in.textureCoorinates, velocity, source, data, data.tuning.z);
}

fragment half2 divergence(VertexOut fragmentIn [[stage_in]], texture2d<float, access::sample> velocity [[texture(0)]], constant BufferData &bufferData [[buffer(0)]]) {

    constexpr sampler fluid_sampler(filter::nearest);

    float2 uv = fragmentIn.textureCoorinates;

    float2 offsets = bufferData.offsets;

    float2 xOffset = float2(offsets.x, 0.0);
    float2 yOffset = float2(0.0, offsets.y);

    float vl = velocity.sample(fluid_sampler, uv - xOffset).x;
    float vr = velocity.sample(fluid_sampler, uv + xOffset).x;
    float vb = velocity.sample(fluid_sampler, uv - yOffset).y;
    float vt = velocity.sample(fluid_sampler, uv + yOffset).y;

    float scale = 0.5;
    float divergence = scale * (vr - vl + vt - vb);

    return half2(divergence, 0.0);
}

fragment half2 jacobi(VertexOut fragmentIn [[stage_in]], texture2d<half, access::sample> x [[texture(0)]], texture2d<half, access::sample> b [[texture(1)]], constant BufferData &bufferData [[buffer(0)]]) {

    constexpr sampler fluid_sampler(filter::nearest);

    float2 uv = fragmentIn.textureCoorinates;

    float2 offsets = bufferData.offsets;

    float2 xOffset = float2(offsets.x, 0.0);
    float2 yOffset = float2(0.0, offsets.y);

    half xl = x.sample(fluid_sampler, uv - xOffset).x;
    half xr = x.sample(fluid_sampler, uv + xOffset).x;
    half xb = x.sample(fluid_sampler, uv - yOffset).x;
    half xt = x.sample(fluid_sampler, uv + yOffset).x;

    half bc = b.sample(fluid_sampler, uv).x;

    half alpha = -1;
    half beta = 4;

    half result = (xl + xr + xb + xt + alpha * bc) / beta;

    return half2(result, 0.0);
}

fragment half2 vorticity(VertexOut fragmentIn [[stage_in]], texture2d<float, access::sample> velocity [[texture(0)]], constant BufferData &bufferData [[buffer(0)]]) {

    constexpr sampler fluid_sampler(filter::nearest);

    float2 uv = fragmentIn.textureCoorinates;

    float2 offsets = bufferData.offsets;

    float2 xOffset = float2(offsets.x, 0.0);
    float2 yOffset = float2(0.0, offsets.y);

    float vl = velocity.sample(fluid_sampler, uv - xOffset).y;
    float vr = velocity.sample(fluid_sampler, uv + xOffset).y;
    float vb = velocity.sample(fluid_sampler, uv - yOffset).x;
    float vt = velocity.sample(fluid_sampler, uv + yOffset).x;

    float scale = 0.5;

    return half2(scale * ((vr - vl) - (vt - vb)), 0.0);
}

fragment half2 vorticityConfinement(VertexOut fragmentIn [[stage_in]], texture2d<float, access::sample> velocity [[texture(0)]], texture2d<float, access::sample> vorticity [[texture(1)]], constant BufferData &bufferData [[buffer(0)]]) {

    constexpr sampler fluid_sampler(filter::nearest);

    float2 screenSize = bufferData.screenSize;

    float2 uv = fragmentIn.textureCoorinates;

    float2 offsets = bufferData.offsets;

    float2 xOffset = float2(offsets.x, 0.0);
    float2 yOffset = float2(0.0, offsets.y);

    float vl = vorticity.sample(fluid_sampler, uv - xOffset).x;
    float vr = vorticity.sample(fluid_sampler, uv + xOffset).x;
    float vb = vorticity.sample(fluid_sampler, uv - yOffset).x;
    float vt = vorticity.sample(fluid_sampler, uv + yOffset).x;
    float vc = vorticity.sample(fluid_sampler, uv).x;

    float scale = 0.5;

    float timestep = 1.0;
    float epsilon = 2.4414e-4;
    float2 curl = float2(bufferData.tuning.y);


    float2 force = scale * float2(abs(vt) - abs(vb), abs(vr) - abs(vl));
    float lengthSquared = max(epsilon, dot(force, force));
    force *= rsqrt(lengthSquared) * curl * vc;
    force.y *= -1.0;

    float2 velc = velocity.sample(fluid_sampler, uv).xy;
    float2 result = velc + (timestep * force);

    //Boundary
    float2 gridValue = uv * screenSize;
    if(gridValue.x <= 1 || gridValue.y <= 1 || gridValue.x >= screenSize.x - 1 || gridValue.y >= screenSize.y - 1) {
        result = float2(0.0);
    }

    return half2(result.x, result.y);
}

fragment half2 gradient(VertexOut fragmentIn [[stage_in]], texture2d<float, access::sample> p [[texture(0)]], texture2d<float, access::sample> w [[texture(1)]], constant BufferData &bufferData [[buffer(0)]]) {

    constexpr sampler fluid_sampler(filter::nearest);

    float2 screenSize = bufferData.screenSize;

    float2 uv = fragmentIn.textureCoorinates;

    float2 offsets = bufferData.offsets;

    float2 xOffset = float2(offsets.x, 0.0);
    float2 yOffset = float2(0.0, offsets.y);

    float pl = p.sample(fluid_sampler, uv - xOffset).x;
    float pr = p.sample(fluid_sampler, uv + xOffset).x;
    float pb = p.sample(fluid_sampler, uv - yOffset).x;
    float pt = p.sample(fluid_sampler, uv + yOffset).x;

    float scale = 0.5;

    float2 gradient = scale * float2(pr - pl, pt - pb);

    float2 wc = w.sample(fluid_sampler, uv).xy;

    float2 result = wc - gradient;

    //Boundary
    float2 gridValue = uv * screenSize;

    if(gridValue.x <= 1 || gridValue.y <= 1 || gridValue.x >= screenSize.x - 1 || gridValue.y >= screenSize.y - 1) {
        result = float2(0.0);
    }
    return half2(result.x, result.y);
}

fragment half2 scriptedForce(VertexOut in [[stage_in]], texture2d<float> velocity [[texture(0)]],
                             texture2d<float> impulse [[texture(1)]], constant BufferData &data [[buffer(0)]]) {
    constexpr sampler s(filter::nearest);
    return half2(velocity.sample(s, in.textureCoorinates).xy + data.impulseScalar.x * impulse.sample(s, in.textureCoorinates).xy);
}

// Float32 reductions remain on the GPU; presentation consumes them in this command buffer.
kernel void reduceFieldTiles(texture2d<float, access::read> pressure [[texture(0)]],
                             texture2d<float, access::read> velocity [[texture(1)]],
                             texture2d<float, access::read> curl [[texture(2)]],
                             device float4 *partials [[buffer(0)]],
                             uint gid [[thread_position_in_grid]], uint tid [[thread_index_in_threadgroup]],
                             uint group [[threadgroup_position_in_grid]]) {
    threadgroup float4 values[256]; threadgroup float curls[256];
    uint count = pressure.get_width() * pressure.get_height();
    float4 v = float4(0, INFINITY, -INFINITY, 0); float c = 0;
    if (gid < count) {
        uint2 p(gid % pressure.get_width(), gid / pressure.get_width());
        float pressureValue = pressure.read(p).x;
        v = float4(pressureValue, pressureValue, pressureValue, length(velocity.read(p).xy));
        c = abs(curl.read(p).x);
    }
    values[tid] = v; curls[tid] = c; threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            float4 b = values[tid + stride], a = values[tid];
            values[tid] = float4(a.x + b.x, min(a.y, b.y), max(a.z, b.z), max(a.w, b.w));
            curls[tid] = max(curls[tid], curls[tid + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (tid == 0) { partials[group * 2] = values[0]; partials[group * 2 + 1] = float4(curls[0], 0, 0, 0); }
}
kernel void reduceFieldStatistics(device const float4 *partials [[buffer(0)]], device float4 &statistics [[buffer(1)]],
                                  constant uint2 &counts [[buffer(2)]], uint tid [[thread_index_in_threadgroup]]) {
    threadgroup float4 values[256]; threadgroup float curls[256];
    float4 a(0, INFINITY, -INFINITY, 0); float c = 0;
    for (uint i = tid; i < counts.x; i += 256) {
        float4 b = partials[i * 2];
        a = float4(a.x + b.x, min(a.y, b.y), max(a.z, b.z), max(a.w, b.w));
        c = max(c, partials[i * 2 + 1].x);
    }
    values[tid] = a; curls[tid] = c; threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            float4 b = values[tid + stride], a = values[tid];
            values[tid] = float4(a.x + b.x, min(a.y, b.y), max(a.z, b.z), max(a.w, b.w));
            curls[tid] = max(curls[tid], curls[tid + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (tid == 0) {
        float mean = values[0].x / float(counts.y);
        statistics = float4(mean, max(1e-5f, values[0].w), max(1e-5f, curls[0]),
                            max(1e-5f, max(abs(values[0].y - mean), abs(values[0].z - mean))));
    }
}
fragment float4 displayField(VertexOut in [[stage_in]], texture2d<float> field [[texture(0)]],
                             constant float4 &stats [[buffer(0)]], constant uint &choice [[buffer(1)]]) {
    constexpr sampler s(filter::nearest);
    float2 value = field.sample(s, in.textureCoorinates).xy;
    float3 color;
    if (choice == 0) {
        float concentration = max(0.0f, value.x), t = concentration / (1 + concentration);
        color = t < 0.5 ? mix(float3(0), float3(0.02, 0.32, 0.85), t * 2) : mix(float3(0.02, 0.32, 0.85), float3(0.8, 1, 1), (t - 0.5) * 2);
    } else if (choice == 2) {
        float t = saturate(length(value) / stats.y);
        color = t < 0.5 ? mix(float3(0.09, 0.02, 0.18), float3(0.02, 0.65, 0.60), t * 2) : mix(float3(0.02, 0.65, 0.60), float3(1, 0.92, 0.20), (t - 0.5) * 2);
    } else {
        // Positive curl is clockwise in downward-positive texture coordinates.
        float signedValue = choice == 1 ? (value.x - stats.x) / stats.w : value.x / stats.z;
        color = mix(float3(0.88), signedValue < 0 ? float3(0.08, 0.35, 0.85) : float3(0.95, 0.38, 0.06), saturate(abs(signedValue)));
    }
    return float4(color, 1);
}
struct OverlayOut { float4 position [[position]]; float2 local; float alpha; };
constant float2 quadCorners[6] = {float2(-1,-1), float2(1,-1), float2(-1,1), float2(-1,1), float2(1,-1), float2(1,1)};
vertex OverlayOut arrowVertex(uint vid [[vertex_id]], uint instance [[instance_id]],
                               texture2d<float> velocity [[texture(0)]], constant float4 &p [[buffer(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    uint columns = uint(p.z);
    float2 uv = (float2(instance % columns, instance / columns) + 0.5) / p.zw;
    float2 v = velocity.sample(s, uv).xy; float speed = length(v);
    float2 direction = speed >= 1e-5 ? v / speed : float2(1, 0);
    float2 local = quadCorners[vid];
    float2 offset = (direction * local.x + float2(-direction.y, direction.x) * local.y) * 11 / p.xy;
    float2 xy = (uv + offset) * 2 - 1;
    return {float4(xy.x, -xy.y, 0, 1), local, speed >= 1e-5 ? 1.0f : 0.0f};
}
inline float segmentDistance(float2 p, float2 a, float2 b) {
    float2 v = b - a; return length(p - a - v * saturate(dot(p - a, v) / dot(v, v)));
}
fragment float4 arrowFragment(OverlayOut in [[stage_in]]) {
    float d = min(segmentDistance(in.local, float2(-0.8, 0), float2(0.8, 0)),
                  min(segmentDistance(in.local, float2(0.8, 0), float2(0.3, -0.45)), segmentDistance(in.local, float2(0.8, 0), float2(0.3, 0.45))));
    float alpha = (1 - smoothstep(0.13, 0.18, d)) * in.alpha;
    return float4(float3(1 - smoothstep(0.035, 0.08, d)), alpha);
}

kernel void resetParticles(device float2 *positions [[buffer(0)]], device float2 *history [[buffer(1)]], uint i [[thread_position_in_grid]]) {
    float2 p = 0.1 + 0.8 * float2(i % 16, i / 16) / 15.0;
    positions[i] = p; history[i * 64] = p;
}
kernel void advanceParticles(device float2 *positions [[buffer(0)]], device float2 *history [[buffer(1)]],
                             constant uint &slot [[buffer(2)]], texture2d<float> velocity [[texture(0)]], uint i [[thread_position_in_grid]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 grid(velocity.get_width(), velocity.get_height());
    float2 lower = min(float2(0.5), 1.5 / grid), upper = 1 - lower;
    float2 p = positions[i];
    float2 midpoint = clamp(p + 0.5 * velocity.sample(s, p).xy / grid, lower, upper);
    p = clamp(p + velocity.sample(s, midpoint).xy / grid, lower, upper);
    // Invalid values are deliberately not hidden: regression readback checks finiteness.
    positions[i] = p; history[i * 64 + slot] = p;
}
vertex OverlayOut particleVertex(uint vid [[vertex_id]], uint i [[instance_id]], device const float2 *positions [[buffer(0)]], constant float4 &p [[buffer(2)]]) {
    float2 local = quadCorners[vid]; float2 xy = (positions[i] + local * 3.5 / p.xy) * 2 - 1;
    return {float4(xy.x, -xy.y, 0, 1), local, 1};
}
fragment float4 particleFragment(OverlayOut in [[stage_in]]) {
    float radius = length(in.local);
    return float4(float3(1 - smoothstep(0.45, 0.65, radius)), 1 - smoothstep(0.85, 1.0, radius));
}
vertex OverlayOut trailVertex(uint vid [[vertex_id]], uint instance [[instance_id]], device const float2 *history [[buffer(1)]], constant float4 &p [[buffer(2)]]) {
    uint count = uint(p.w), segment = instance % (count - 1), particle = instance / (count - 1);
    uint oldest = (uint(p.z) + 64 - count + 1) % 64;
    float2 a = history[particle * 64 + (oldest + segment) % 64];
    float2 b = history[particle * 64 + (oldest + segment + 1) % 64];
    float2 delta = (b - a) * p.xy;
    float lengthPixels = length(delta);
    float2 normal = lengthPixels > 1e-6 ? float2(-delta.y, delta.x) / lengthPixels : float2(0);
    float2 local = quadCorners[vid];
    float2 point = mix(a, b, (local.x + 1) * 0.5) + normal * local.y * 1.5 / p.xy;
    float2 xy = point * 2 - 1;
    return {float4(xy.x, -xy.y, 0, 1), local, lengthPixels > 1e-6 ? (0.1 + 0.65 * float(segment + 1) / float(count - 1)) : 0.0f};
}
fragment float4 trailFragment(OverlayOut in [[stage_in]]) {
    float d = abs(in.local.y);
    return float4(float3(1 - smoothstep(0.3, 0.7, d)), in.alpha * (1 - smoothstep(0.7, 1.0, d)));
}

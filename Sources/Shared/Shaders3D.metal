#include <metal_stdlib>
using namespace metal;

// Must match Fluid3DUniforms exactly: 3 x 16-byte Swift/Metal lanes.
struct Fluid3DUniforms {
    uint4 grid;
    float4 scale;
    uint4 output;
};

struct Fluid3DSliceVertex {
    float2 position;
    float2 worldXY;
};

struct Fluid3DSliceVertexOutput {
    float4 position [[position]];
    float2 worldXY [[user(locn0)]];
};

struct Fluid3DSlicePalette {
    float4 black;
    float4 amber;
    float4 cream;
    float4 stops;
};

// Must match FieldVisualization3D.SpatialInspectionUniforms exactly:
// worldToClip@0, slice@64, viewport@80, stride 96/alignment 16.
struct Fluid3DInspectionUniforms {
    float4x4 worldToClip;
    float4 slice;
    float4 viewport;
};

struct Fluid3DSpatialSliceOutput {
    float4 position [[position]];
    float3 worldPosition [[user(locn0)]];
};

struct Fluid3DSpatialGuideOutput {
    float4 position [[position]];
};

vertex Fluid3DSliceVertexOutput fluid3DVertex(
    const device Fluid3DSliceVertex *vertices [[buffer(0)]],
    uint vertexID [[vertex_id]]) {
    Fluid3DSliceVertexOutput output;
    output.position = float4(vertices[vertexID].position, 0.0f, 1.0f);
    output.worldXY = vertices[vertexID].worldXY;
    return output;
}

inline float fluid3DSampleCentralXY(
    texture3d<float, access::read> dye,
    float2 worldXY) {
    float3 extent = float3(float(dye.get_width()), float(dye.get_height()), float(dye.get_depth()));
    float3 coordinate = clamp(float3(worldXY, 0.5f) * extent - 0.5f, 0.0f, extent - 1.0f);
    int3 lower = int3(floor(coordinate));
    int3 upper = min(lower + 1, int3(extent) - 1);
    float3 fraction = coordinate - float3(lower);

    float c000 = dye.read(uint3(lower.x, lower.y, lower.z)).x;
    float c100 = dye.read(uint3(upper.x, lower.y, lower.z)).x;
    float c010 = dye.read(uint3(lower.x, upper.y, lower.z)).x;
    float c110 = dye.read(uint3(upper.x, upper.y, lower.z)).x;
    float c001 = dye.read(uint3(lower.x, lower.y, upper.z)).x;
    float c101 = dye.read(uint3(upper.x, lower.y, upper.z)).x;
    float c011 = dye.read(uint3(lower.x, upper.y, upper.z)).x;
    float c111 = dye.read(uint3(upper.x, upper.y, upper.z)).x;

    float lowerPlane = mix(
        mix(c000, c100, fraction.x),
        mix(c010, c110, fraction.x),
        fraction.y);
    float upperPlane = mix(
        mix(c001, c101, fraction.x),
        mix(c011, c111, fraction.x),
        fraction.y);
    return mix(lowerPlane, upperPlane, fraction.z);
}

fragment float4 fluid3DFixedSlice(
    Fluid3DSliceVertexOutput input [[stage_in]],
    texture3d<float, access::read> dye [[texture(0)]],
    constant Fluid3DSlicePalette &palette [[buffer(0)]]) {
    float concentration = clamp(fluid3DSampleCentralXY(dye, input.worldXY), 0.0f, 1.0f);
    float3 encodedRGB;
    if (concentration <= palette.stops.y) {
        float amount = (concentration - palette.stops.x) / (palette.stops.y - palette.stops.x);
        encodedRGB = mix(palette.black.rgb, palette.amber.rgb, amount);
    } else {
        float amount = (concentration - palette.stops.y) / (palette.stops.z - palette.stops.y);
        encodedRGB = mix(palette.amber.rgb, palette.cream.rgb, amount);
    }
    // The palette is already expressed in encoded channel values. The
    // non-sRGB bgra8Unorm render target stores these values without another OETF.
    return float4(encodedRGB, 1.0f);
}

vertex Fluid3DSpatialSliceOutput fluid3DSpatialVertex(
    uint vertexID [[vertex_id]],
    constant Fluid3DInspectionUniforms &uniforms [[buffer(0)]]) {
    float2 local = float2(float(vertexID & 1u), float((vertexID >> 1u) & 1u));
    float3 worldPosition;
    uint plane = uint(uniforms.slice.y + 0.5f);
    if (plane == 0u) {
        worldPosition = float3(local.x, local.y, uniforms.slice.x);
    } else if (plane == 1u) {
        worldPosition = float3(local.x, uniforms.slice.x, local.y);
    } else {
        worldPosition = float3(uniforms.slice.x, local.y, local.x);
    }
    Fluid3DSpatialSliceOutput output;
    output.position = uniforms.worldToClip * float4(worldPosition, 1.0f);
    output.worldPosition = worldPosition;
    return output;
}

inline float fluid3DSampleSpatial(
    texture3d<float, access::read> dye,
    float3 worldPosition) {
    float3 extent = float3(float(dye.get_width()), float(dye.get_height()), float(dye.get_depth()));
    float3 coordinate = clamp(worldPosition * extent - 0.5f, 0.0f, extent - 1.0f);
    int3 lower = int3(floor(coordinate));
    int3 upper = min(lower + 1, int3(extent) - 1);
    float3 fraction = coordinate - float3(lower);
    float c000 = dye.read(uint3(lower.x, lower.y, lower.z)).x;
    float c100 = dye.read(uint3(upper.x, lower.y, lower.z)).x;
    float c010 = dye.read(uint3(lower.x, upper.y, lower.z)).x;
    float c110 = dye.read(uint3(upper.x, upper.y, lower.z)).x;
    float c001 = dye.read(uint3(lower.x, lower.y, upper.z)).x;
    float c101 = dye.read(uint3(upper.x, lower.y, upper.z)).x;
    float c011 = dye.read(uint3(lower.x, upper.y, upper.z)).x;
    float c111 = dye.read(uint3(upper.x, upper.y, upper.z)).x;
    float lowerPlane = mix(
        mix(c000, c100, fraction.x),
        mix(c010, c110, fraction.x),
        fraction.y);
    float upperPlane = mix(
        mix(c001, c101, fraction.x),
        mix(c011, c111, fraction.x),
        fraction.y);
    return mix(lowerPlane, upperPlane, fraction.z);
}

fragment float4 fluid3DSpatialSlice(
    Fluid3DSpatialSliceOutput input [[stage_in]],
    texture3d<float, access::read> dye [[texture(0)]],
    constant Fluid3DSlicePalette &palette [[buffer(0)]]) {
    float concentration = clamp(fluid3DSampleSpatial(dye, input.worldPosition), 0.0f, 1.0f);
    float3 encodedRGB;
    if (concentration <= palette.stops.y) {
        float amount = (concentration - palette.stops.x) / (palette.stops.y - palette.stops.x);
        encodedRGB = mix(palette.black.rgb, palette.amber.rgb, amount);
    } else {
        float amount = (concentration - palette.stops.y) / (palette.stops.z - palette.stops.y);
        encodedRGB = mix(palette.amber.rgb, palette.cream.rgb, amount);
    }
    return float4(encodedRGB, 1.0f);
}

inline float3 fluid3DUnitCubeVertex(uint index) {
    switch (index) {
        case 0u: return float3(0.0f, 0.0f, 0.0f);
        case 1u: return float3(1.0f, 0.0f, 0.0f);
        case 2u: return float3(0.0f, 1.0f, 0.0f);
        case 3u: return float3(1.0f, 1.0f, 0.0f);
        case 4u: return float3(0.0f, 0.0f, 1.0f);
        case 5u: return float3(1.0f, 0.0f, 1.0f);
        case 6u: return float3(0.0f, 1.0f, 1.0f);
        default: return float3(1.0f, 1.0f, 1.0f);
    }
}

inline uint2 fluid3DUnitCubeEdge(uint index) {
    switch (index) {
        case 0u: return uint2(0u, 1u);
        case 1u: return uint2(2u, 3u);
        case 2u: return uint2(4u, 5u);
        case 3u: return uint2(6u, 7u);
        case 4u: return uint2(0u, 2u);
        case 5u: return uint2(1u, 3u);
        case 6u: return uint2(4u, 6u);
        case 7u: return uint2(5u, 7u);
        case 8u: return uint2(0u, 4u);
        case 9u: return uint2(1u, 5u);
        case 10u: return uint2(2u, 6u);
        default: return uint2(3u, 7u);
    }
}

vertex Fluid3DSpatialGuideOutput fluid3DSpatialGuideVertex(
    uint vertexID [[vertex_id]],
    constant Fluid3DInspectionUniforms &uniforms [[buffer(0)]]) {
    uint corner = vertexID % 6u;
    uint2 edge = fluid3DUnitCubeEdge(vertexID / 6u);
    float4 startClip = uniforms.worldToClip * float4(fluid3DUnitCubeVertex(edge.x), 1.0f);
    float4 endClip = uniforms.worldToClip * float4(fluid3DUnitCubeVertex(edge.y), 1.0f);
    float2 startNDC = startClip.xy / startClip.w;
    float2 endNDC = endClip.xy / endClip.w;
    float2 screenDelta = (endNDC - startNDC) * float2(
        uniforms.viewport.x * 0.5f,
        -uniforms.viewport.y * 0.5f
    );
    float pixelLength = length(screenDelta);
    float2 direction = pixelLength > 0.0001f
        ? screenDelta / pixelLength
        : float2(1.0f, 0.0f);
    float2 normal = float2(-direction.y, direction.x);

    uint endpointIndex;
    float side;
    switch (corner) {
        case 0u:
            endpointIndex = 0u;
            side = -1.0f;
            break;
        case 1u:
            endpointIndex = 0u;
            side = 1.0f;
            break;
        case 2u:
        case 3u:
            endpointIndex = 1u;
            side = -1.0f;
            break;
        case 4u:
            endpointIndex = 0u;
            side = 1.0f;
            break;
        default:
            endpointIndex = 1u;
            side = 1.0f;
            break;
    }

    float4 position = endpointIndex == 0u ? startClip : endClip;
    float halfWidthPixels = uniforms.viewport.z * 0.5f;
    float2 ndcOffset = normal * side * halfWidthPixels * float2(
        2.0f / uniforms.viewport.x,
        -2.0f / uniforms.viewport.y
    );
    position.xy += ndcOffset * position.w;
    Fluid3DSpatialGuideOutput output;
    output.position = position;
    return output;
}

fragment float4 fluid3DSpatialGuide(
    Fluid3DSpatialGuideOutput input [[stage_in]],
    constant float4 &color [[buffer(0)]]) {
    return color;
}

kernel void fluid3DABIRoundTrip(
    constant Fluid3DUniforms &input [[buffer(0)]],
    device Fluid3DUniforms *output [[buffer(1)]],
    uint threadIndex [[thread_position_in_grid]]) {
    if (threadIndex != 0) {
        return;
    }
    output[0] = input;
}

kernel void fluid3DInspectionABIRoundTrip(
    constant Fluid3DInspectionUniforms &input [[buffer(0)]],
    device Fluid3DInspectionUniforms *output [[buffer(1)]],
    uint threadIndex [[thread_position_in_grid]]) {
    if (threadIndex == 0) {
        output[0] = input;
    }
}

kernel void fluid3DClear(
    texture3d<float, access::write> output [[texture(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width()
        || position.y >= output.get_height()
        || position.z >= output.get_depth()) {
        return;
    }
    output.write(0.0f, position);
}

inline float foldCoordinate(float coordinate, float extent, thread float &sign) {
    float folded = fmod(coordinate, 2.0f * extent);
    if (folded < 0.0f) {
        folded += 2.0f * extent;
    }
    if (folded <= extent) {
        sign = 1.0f;
        return folded;
    }
    sign = -1.0f;
    return 2.0f * extent - folded;
}

inline int reflectCellIndex(int index, int count) {
    while (index < 0 || index >= count) {
        if (index < 0) {
            index = -index - 1;
        }
        if (index >= count) {
            index = 2 * count - 1 - index;
        }
    }
    return index;
}

// Cell/scalar and each MAC component share this one reflected trilinear
// sampler. normalAxis==-1 selects an even scalar extension; velocity uses an
// odd extension only across its own normal walls and even tangential parity.
inline float sampleLattice(
    texture3d<float, access::read> field,
    float3 position,
    float3 offsets,
    float spacing,
    float3 domainCells,
    int normalAxis) {
    float3 lengths = spacing * domainCells;
    float signX;
    float signY;
    float signZ;
    float3 folded = float3(
        foldCoordinate(position.x, lengths.x, signX),
        foldCoordinate(position.y, lengths.y, signY),
        foldCoordinate(position.z, lengths.z, signZ));
    float3 coordinate = folded / spacing - offsets;
    int3 base = int3(floor(coordinate));
    float3 fraction = coordinate - float3(base);
    int3 dimensions = int3(field.get_width(), field.get_height(), field.get_depth());
    float total = 0.0f;

    for (int dz = 0; dz <= 1; ++dz) {
        for (int dy = 0; dy <= 1; ++dy) {
            for (int dx = 0; dx <= 1; ++dx) {
                int3 index = base + int3(dx, dy, dz);
                for (int axis = 0; axis < 3; ++axis) {
                    if (axis == normalAxis) {
                        index[axis] = clamp(index[axis], 0, dimensions[axis] - 1);
                    } else {
                        index[axis] = reflectCellIndex(index[axis], dimensions[axis]);
                    }
                }
                float wx = dx == 0 ? 1.0f - fraction.x : fraction.x;
                float wy = dy == 0 ? 1.0f - fraction.y : fraction.y;
                float wz = dz == 0 ? 1.0f - fraction.z : fraction.z;
                total += field.read(uint3(index)).x * wx * wy * wz;
            }
        }
    }
    if (normalAxis == 0) {
        total *= signX;
    } else if (normalAxis == 1) {
        total *= signY;
    } else if (normalAxis == 2) {
        total *= signZ;
    }
    return total;
}

inline float3 sampleVelocity(
    texture3d<float, access::read> u,
    texture3d<float, access::read> v,
    texture3d<float, access::read> w,
    float3 position,
    float spacing,
    float3 domainCells) {
    return float3(
        sampleLattice(u, position, float3(0.0f, 0.5f, 0.5f), spacing, domainCells, 0),
        sampleLattice(v, position, float3(0.5f, 0.0f, 0.5f), spacing, domainCells, 1),
        sampleLattice(w, position, float3(0.5f, 0.5f, 0.0f), spacing, domainCells, 2));
}

inline float3 backtraceRK2(
    texture3d<float, access::read> u,
    texture3d<float, access::read> v,
    texture3d<float, access::read> w,
    float3 position,
    constant Fluid3DUniforms &uniforms) {
    float spacing = uniforms.scale.x;
    float dt = uniforms.scale.y;
    float3 domainCells = float3(uniforms.grid.xyz);
    float3 maximum = spacing * domainCells;
    float3 velocity0 = sampleVelocity(u, v, w, position, spacing, domainCells);
    float3 midpoint = clamp(position - 0.5f * dt * velocity0, float3(0.0f), maximum);
    float3 midpointVelocity = sampleVelocity(u, v, w, midpoint, spacing, domainCells);
    return clamp(position - dt * midpointVelocity, float3(0.0f), maximum);
}

inline float3 outputPosition(uint3 position, uint component, float spacing) {
    if (component == 0) {
        return spacing * float3(float(position.x), float(position.y) + 0.5f, float(position.z) + 0.5f);
    }
    if (component == 1) {
        return spacing * float3(float(position.x) + 0.5f, float(position.y), float(position.z) + 0.5f);
    }
    return spacing * float3(float(position.x) + 0.5f, float(position.y) + 0.5f, float(position.z));
}

kernel void fluid3DAdvectVelocity(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> u [[texture(0)]],
    texture3d<float, access::read> v [[texture(1)]],
    texture3d<float, access::read> w [[texture(2)]],
    texture3d<float, access::read> input [[texture(3)]],
    texture3d<float, access::write> output [[texture(4)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= uniforms.output.x || position.y >= uniforms.output.y
        || position.z >= uniforms.output.z || position.x >= output.get_width()
        || position.y >= output.get_height() || position.z >= output.get_depth()) {
        return;
    }
    uint component = uniforms.output.w;
    if (component > 2) {
        return;
    }
    float3 target = outputPosition(position, component, uniforms.scale.x);
    float3 departure = backtraceRK2(u, v, w, target, uniforms);
    float3 offsets = component == 0
        ? float3(0.0f, 0.5f, 0.5f)
        : (component == 1 ? float3(0.5f, 0.0f, 0.5f) : float3(0.5f, 0.5f, 0.0f));
    output.write(sampleLattice(
        input, departure, offsets, uniforms.scale.x, float3(uniforms.grid.xyz), int(component)), position);
}

kernel void fluid3DAdvectDye(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> u [[texture(0)]],
    texture3d<float, access::read> v [[texture(1)]],
    texture3d<float, access::read> w [[texture(2)]],
    texture3d<float, access::read> input [[texture(3)]],
    texture3d<float, access::write> output [[texture(4)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= uniforms.output.x || position.y >= uniforms.output.y
        || position.z >= uniforms.output.z || position.x >= output.get_width()
        || position.y >= output.get_height() || position.z >= output.get_depth()) {
        return;
    }
    float3 target = uniforms.scale.x * (float3(position) + 0.5f);
    float3 departure = backtraceRK2(u, v, w, target, uniforms);
    float value = sampleLattice(
        input, departure, float3(0.5f), uniforms.scale.x, float3(uniforms.grid.xyz), -1);
    output.write(clamp(value, 0.0f, 1.0f), position);
}

kernel void fluid3DEnforceWalls(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read_write> velocity [[texture(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= uniforms.output.x || position.y >= uniforms.output.y
        || position.z >= uniforms.output.z || position.x >= velocity.get_width()
        || position.y >= velocity.get_height() || position.z >= velocity.get_depth()) {
        return;
    }
    uint component = uniforms.output.w;
    bool isWall = (component == 0 && (position.x == 0 || position.x == uniforms.grid.x))
        || (component == 1 && (position.y == 0 || position.y == uniforms.grid.y))
        || (component == 2 && (position.z == 0 || position.z == uniforms.grid.z));
    if (isWall) {
        velocity.write(0.0f, position);
    }
}

kernel void fluid3DDivergence(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> u [[texture(0)]],
    texture3d<float, access::read> v [[texture(1)]],
    texture3d<float, access::read> w [[texture(2)]],
    texture3d<float, access::write> output [[texture(3)]],
    uint3 position [[thread_position_in_grid]]) {
    uint3 cells = uniforms.grid.xyz;
    if (position.x >= cells.x || position.y >= cells.y || position.z >= cells.z
        || position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) {
        return;
    }

    float flux = u.read(position + uint3(1, 0, 0)).x - u.read(position).x
        + v.read(position + uint3(0, 1, 0)).x - v.read(position).x
        + w.read(position + uint3(0, 0, 1)).x - w.read(position).x;
    output.write(flux * uniforms.scale.z, position);
}

kernel void fluid3DApplyA(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> pressure [[texture(0)]],
    texture3d<float, access::write> output [[texture(1)]],
    uint3 position [[thread_position_in_grid]]) {
    uint3 cells = uniforms.grid.xyz;
    if (position.x >= cells.x || position.y >= cells.y || position.z >= cells.z
        || position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) {
        return;
    }

    float center = pressure.read(position).x;
    float sum = 0.0f;
    if (position.x > 0) { sum += center - pressure.read(position - uint3(1, 0, 0)).x; }
    if (position.x + 1 < cells.x) { sum += center - pressure.read(position + uint3(1, 0, 0)).x; }
    if (position.y > 0) { sum += center - pressure.read(position - uint3(0, 1, 0)).x; }
    if (position.y + 1 < cells.y) { sum += center - pressure.read(position + uint3(0, 1, 0)).x; }
    if (position.z > 0) { sum += center - pressure.read(position - uint3(0, 0, 1)).x; }
    if (position.z + 1 < cells.z) { sum += center - pressure.read(position + uint3(0, 0, 1)).x; }
    output.write(sum, position);
}

kernel void fluid3DSubtractGradient(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> pressure [[texture(0)]],
    texture3d<float, access::read> input [[texture(1)]],
    texture3d<float, access::write> output [[texture(2)]],
    uint3 position [[thread_position_in_grid]]) {
    uint component = uniforms.output.w;
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth() || component > 2) {
        return;
    }

    uint3 cells = uniforms.grid.xyz;
    float gradient = 0.0f;
    if (component == 0 && position.x > 0 && position.x < cells.x) {
        gradient = (pressure.read(position).x - pressure.read(position - uint3(1, 0, 0)).x)
            * uniforms.scale.z;
    } else if (component == 1 && position.y > 0 && position.y < cells.y) {
        gradient = (pressure.read(position).x - pressure.read(position - uint3(0, 1, 0)).x)
            * uniforms.scale.z;
    } else if (component == 2 && position.z > 0 && position.z < cells.z) {
        gradient = (pressure.read(position).x - pressure.read(position - uint3(0, 0, 1)).x)
            * uniforms.scale.z;
    }
    output.write(input.read(position).x - gradient, position);
}

kernel void fluid3DComputeRHS(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> divergence [[texture(0)]],
    texture3d<float, access::write> output [[texture(1)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) {
        return;
    }
    float h = uniforms.scale.x;
    output.write(-h * h * divergence.read(position).x, position);
}

kernel void fluid3DComputeResidual(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> divergence [[texture(0)]],
    texture3d<float, access::read> appliedA [[texture(1)]],
    texture3d<float, access::write> output [[texture(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) {
        return;
    }
    float h = uniforms.scale.x;
    float b = -h * h * divergence.read(position).x;
    output.write(b - appliedA.read(position).x, position);
}

kernel void fluid3DIdentityError(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> projectedDivergence [[texture(0)]],
    texture3d<float, access::read> trueResidual [[texture(1)]],
    texture3d<float, access::write> output [[texture(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) {
        return;
    }
    float h = uniforms.scale.x;
    output.write(projectedDivergence.read(position).x + trueResidual.read(position).x / (h * h), position);
}

inline float4 reducePair(float4 left, float4 right) {
    return float4(left.x + right.x, left.y + right.y, max(left.z, right.z), min(left.w, right.w));
}

inline bool pcgActive(device const float4 *state) {
    return state[16].y == 0.0f && state[16].z == 0.0f;
}

inline float neighborDegree(uint3 position, uint3 cells) {
    return float((position.x > 0) + (position.x + 1 < cells.x)
        + (position.y > 0) + (position.y + 1 < cells.y)
        + (position.z > 0) + (position.z + 1 < cells.z));
}

// Error-free additions require source evaluation order, including when the
// surrounding project enables fast math. Both lanes remain ordinary Float32.
#pragma clang fp reassociate(off)
#pragma clang fp contract(off)
inline float2 pressureAdd(float2 value, float increment) {
    float sum = value.x + increment;
    float back = sum - value.x;
    float error = (value.x - (sum - back)) + (increment - back);
    error += value.y;
    float high = sum + error;
    return float2(high, error - (high - sum));
}

inline float2 pressureDifference(
    texture3d<float, access::read> high,
    texture3d<float, access::read> low,
    uint3 center, uint3 neighbor) {
    float2 result = pressureAdd(float2(high.read(center).x, low.read(center).x), -high.read(neighbor).x);
    return pressureAdd(result, -low.read(neighbor).x);
}

inline float compensatedA(
    texture3d<float, access::read> high,
    texture3d<float, access::read> low,
    uint3 p, uint3 cells) {
    float2 sum = float2(0.0f);
    for (uint axis = 0; axis < 3; ++axis) {
        for (uint side = 0; side < 2; ++side) {
            bool included = side == 0 ? p[axis] > 0 : p[axis] + 1 < cells[axis];
            if (included) {
                uint3 neighbor = p;
                neighbor[axis] = side == 0 ? p[axis] - 1 : p[axis] + 1;
                float2 difference = pressureDifference(high, low, p, neighbor);
                sum = pressureAdd(pressureAdd(sum, difference.x), difference.y);
            }
        }
    }
    return sum.x + sum.y;
}

kernel void fluid3DApplyACompensated(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> high [[texture(0)]],
    texture3d<float, access::write> output [[texture(1)]],
    texture3d<float, access::read> low [[texture(2)]],
    uint3 p [[thread_position_in_grid]]) {
    if (any(p >= uniforms.grid.xyz)) { return; }
    output.write(compensatedA(high, low, p, uniforms.grid.xyz), p);
}

kernel void fluid3DSubtractGradientCompensated(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> high [[texture(0)]],
    texture3d<float, access::read> input [[texture(1)]],
    texture3d<float, access::write> output [[texture(2)]],
    texture3d<float, access::read> low [[texture(3)]],
    uint3 p [[thread_position_in_grid]]) {
    if (any(p >= uniforms.output.xyz)) { return; }
    uint axis = uniforms.output.w;
    float2 gradient = float2(0.0f);
    if (p[axis] > 0 && p[axis] < uniforms.grid[axis]) {
        uint3 previous = p;
        previous[axis] -= 1;
        gradient = pressureDifference(high, low, p, previous) * uniforms.scale.z;
    }
    float2 value = pressureAdd(float2(input.read(p).x, 0.0f), -gradient.x);
    value = pressureAdd(value, -gradient.y);
    output.write(value.x + value.y, p);
}

kernel void fluid3DInitializeSolverState(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device float4 *state [[buffer(1)]],
    device const uint *failureLatch [[buffer(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0))) { return; }
    for (uint lane = 0; lane < 19; ++lane) { state[lane] = float4(0.0f); }
    float h = uniforms.scale.x;
    float dt = uniforms.scale.y;
    state[16] = float4(0.0f, 0.0f, 0.0f, 0.0f);
    state[18].x = float(uniforms.output.y);
    if (uniforms.output.y != 0 && failureLatch[0] != 0) { state[16].y = 12.0f; }
    // The contractual dt-scaled residual remains the final acceptance gate.
    // Coarse fixtures need a stricter internal stop to meet the independently
    // preregistered Float-vs-Double elementwise comparison tolerance; at 64^3
    // the contract target is already below this additional q-unit ceiling.
    state[17] = float4(float(uniforms.output.w), float(uniforms.grid.w),
        min(1e-5f * h * h / dt, 1e-6f), 0.0f);
}

kernel void fluid3DInitializeProjectionStatus(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device float4 *state [[buffer(1)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0))) { return; }
    if (state[16].y != 0.0f) { return; }
    float4 rhs = state[1];
    float4 u = state[2];
    float4 v = state[3];
    float4 w = state[4];
    float4 walls = state[5];
    uint cells = uniforms.grid.x * uniforms.grid.y * uniforms.grid.z;
    float maximumVelocity = max(u.z, max(v.z, w.z));
    float rhsMean = rhs.x / float(cells);
    float compatibilityBound = 64.0f * 1.1920928955078125e-7f
        * max(max(rhs.z, uniforms.scale.x * maximumVelocity), 1e-30f);
    float inputDivergenceDT = uniforms.scale.y * rhs.z / (uniforms.scale.x * uniforms.scale.x);
    state[14] = float4(rhsMean, compatibilityBound, inputDivergenceDT, maximumVelocity);

    if (rhs.w < 1.0f || u.w < 1.0f || v.w < 1.0f || w.w < 1.0f || walls.w < 1.0f
        || !all(isfinite(state[14]))) {
        state[16].y = 1.0f;
        return;
    }
    if (abs(rhsMean) > compatibilityBound) {
        state[16].y = 2.0f;
        return;
    }
    if (walls.z != 0.0f) {
        state[16].y = 3.0f;
        return;
    }
    if (rhs.z <= state[17].z) { state[16].z = 1.0f; }
}

kernel void fluid3DInitializePCGFields(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device float4 *state [[buffer(1)]],
    texture3d<float, access::read> rhs [[texture(0)]],
    texture3d<float, access::write> pressure [[texture(1)]],
    texture3d<float, access::write> residual [[texture(2)]],
    texture3d<float, access::write> preconditioned [[texture(3)]],
    texture3d<float, access::write> pressureLow [[texture(4)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= pressure.get_width() || position.y >= pressure.get_height()
        || position.z >= pressure.get_depth()) { return; }
    pressure.write(0.0f, position);
    pressureLow.write(0.0f, position);
    if (!pcgActive(state)) {
        residual.write(0.0f, position);
        preconditioned.write(0.0f, position);
        return;
    }
    float value = rhs.read(position).x - state[14].x;
    residual.write(value, position);
    float degree = neighborDegree(position, uniforms.grid.xyz);
    preconditioned.write(degree > 0.0f ? value / degree : 0.0f, position);
}

kernel void fluid3DReduceDot(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> left [[texture(0)]],
    texture3d<float, access::read> right [[texture(1)]],
    device float4 *partials [[buffer(1)]],
    uint3 position [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 groupPosition [[threadgroup_position_in_grid]],
    uint3 groupWidth [[threads_per_threadgroup]]) {
    threadgroup float4 values[256];
    uint width = groupWidth.x;
    uint index = position.x;
    uint count = uniforms.output.x * uniforms.output.y * uniforms.output.z;
    float4 local = float4(0.0f, 0.0f, 0.0f, 1.0f);
    if (index < count) {
        uint x = index % uniforms.output.x;
        uint y = (index / uniforms.output.x) % uniforms.output.y;
        uint z = index / (uniforms.output.x * uniforms.output.y);
        float a = left.read(uint3(x, y, z)).x;
        float b = right.read(uint3(x, y, z)).x;
        float product = a * b;
        float square = product * product;
        if (isfinite(a) && isfinite(b) && isfinite(product) && isfinite(square)) {
            local = float4(product, square, abs(product), 1.0f);
        } else {
            local.w = 0.0f;
        }
    }
    values[lane] = local;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = width / 2; stride > 0; stride >>= 1) {
        if (lane < stride) { values[lane] = reducePair(values[lane], values[lane + stride]); }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) { partials[groupPosition.x] = values[0]; }
}

kernel void fluid3DReducePCGState(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> pressure [[texture(0)]],
    texture3d<float, access::read> residual [[texture(1)]],
    device float4 *partials [[buffer(1)]],
    uint3 position [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 groupPosition [[threadgroup_position_in_grid]],
    uint3 groupWidth [[threads_per_threadgroup]]) {
    threadgroup float4 values[256];
    uint width = groupWidth.x;
    uint index = position.x;
    uint count = uniforms.output.x * uniforms.output.y * uniforms.output.z;
    float4 local = float4(0.0f, 0.0f, 0.0f, 1.0f);
    if (index < count) {
        uint x = index % uniforms.output.x;
        uint y = (index / uniforms.output.x) % uniforms.output.y;
        uint z = index / (uniforms.output.x * uniforms.output.y);
        float q = pressure.read(uint3(x, y, z)).x;
        float r = residual.read(uint3(x, y, z)).x;
        if (isfinite(q) && isfinite(r)) {
            local = float4(q, r, max(abs(q), abs(r)), 1.0f);
        } else {
            local.w = 0.0f;
        }
    }
    values[lane] = local;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = width / 2; stride > 0; stride >>= 1) {
        if (lane < stride) { values[lane] = reducePair(values[lane], values[lane + stride]); }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) { partials[groupPosition.x] = values[0]; }
}

kernel void fluid3DProjectPressureResidual(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *state [[buffer(1)]],
    texture3d<float, access::read_write> pressure [[texture(0)]],
    texture3d<float, access::read_write> residual [[texture(1)]],
    texture3d<float, access::read_write> pressureLow [[texture(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= pressure.get_width() || position.y >= pressure.get_height()
        || position.z >= pressure.get_depth()) { return; }
    if (!pcgActive(state)) { return; }
    uint count = uniforms.grid.x * uniforms.grid.y * uniforms.grid.z;
    float2 q = pressureAdd(float2(pressure.read(position).x, pressureLow.read(position).x),
        -state[8].x / float(count));
    pressure.write(q.x, position);
    pressureLow.write(q.y, position);
    residual.write(residual.read(position).x - state[8].y / float(count), position);
}

kernel void fluid3DPreconditionVector(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device float4 *state [[buffer(1)]],
    texture3d<float, access::read> residual [[texture(0)]],
    texture3d<float, access::read> trueResidual [[texture(1)]],
    texture3d<float, access::write> output [[texture(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) { return; }
    if (!pcgActive(state) || state[15].w == 1.0f) {
        output.write(0.0f, position);
        return;
    }
    float source = state[15].w == 2.0f
        ? trueResidual.read(position).x - state[11].x / float(uniforms.grid.x * uniforms.grid.y * uniforms.grid.z)
        : residual.read(position).x;
    float degree = neighborDegree(position, uniforms.grid.xyz);
    output.write(degree > 0.0f ? source / degree : 0.0f, position);
}

kernel void fluid3DProjectPreconditioner(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *state [[buffer(1)]],
    texture3d<float, access::read> input [[texture(0)]],
    texture3d<float, access::write> output [[texture(1)]],
    texture3d<float, access::write> initialDirection [[texture(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) { return; }
    if (!pcgActive(state)) {
        output.write(0.0f, position);
        initialDirection.write(0.0f, position);
        return;
    }
    uint count = uniforms.grid.x * uniforms.grid.y * uniforms.grid.z;
    float value = input.read(position).x - state[7].x / float(count);
    output.write(value, position);
    initialDirection.write(value, position);
}

kernel void fluid3DInitializeRho(
    device float4 *state [[buffer(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0)) || !pcgActive(state)) { return; }
    float rho = state[6].x;
    if (!isfinite(rho) || rho <= 0.0f || state[6].w < 1.0f) {
        state[16].y = 4.0f;
        return;
    }
    state[0].x = rho;
}

kernel void fluid3DApplyASearch(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *state [[buffer(1)]],
    texture3d<float, access::read> pressure [[texture(0)]],
    texture3d<float, access::write> output [[texture(1)]],
    uint3 position [[thread_position_in_grid]]) {
    uint3 cells = uniforms.grid.xyz;
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) { return; }
    if (!pcgActive(state)) { output.write(0.0f, position); return; }
    float center = pressure.read(position).x;
    float sum = 0.0f;
    if (position.x > 0) { sum += center - pressure.read(position - uint3(1, 0, 0)).x; }
    if (position.x + 1 < cells.x) { sum += center - pressure.read(position + uint3(1, 0, 0)).x; }
    if (position.y > 0) { sum += center - pressure.read(position - uint3(0, 1, 0)).x; }
    if (position.y + 1 < cells.y) { sum += center - pressure.read(position + uint3(0, 1, 0)).x; }
    if (position.z > 0) { sum += center - pressure.read(position - uint3(0, 0, 1)).x; }
    if (position.z + 1 < cells.z) { sum += center - pressure.read(position + uint3(0, 0, 1)).x; }
    output.write(sum, position);
}

kernel void fluid3DPreparePCGUpdate(
    device float4 *state [[buffer(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0)) || !pcgActive(state)) { return; }
    float denominator = state[6].x;
    if (state[17].x == 1.0f) { denominator = 0.0f; }
    if (state[17].x == 2.0f) { denominator = -1.0f; }
    if (state[17].x == 3.0f) { denominator = as_type<float>(0x7fc00000u); }
    if (!isfinite(denominator) || denominator <= 0.0f || state[6].w < 1.0f) {
        state[16].y = 5.0f;
        return;
    }
    float alpha = state[0].x / denominator;
    if (!isfinite(alpha)) { state[16].y = 6.0f; return; }
    state[0].y = alpha;
    state[0].w = denominator;
    state[16].x += 1.0f;
}

kernel void fluid3DValidateSummary(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device float4 *state [[buffer(1)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0)) || state[16].y != 0.0f) { return; }
    float4 summary = state[uniforms.output.w];
    if (summary.w < 1.0f || !all(isfinite(summary))) { state[16].y = float(uniforms.output.z); }
}

kernel void fluid3DPCGUpdate(
    device const float4 *state [[buffer(0)]],
    texture3d<float, access::read_write> pressure [[texture(0)]],
    texture3d<float, access::read_write> residual [[texture(1)]],
    texture3d<float, access::read> direction [[texture(2)]],
    texture3d<float, access::read> appliedDirection [[texture(3)]],
    texture3d<float, access::read_write> pressureLow [[texture(4)]],
    uint3 position [[thread_position_in_grid]]) {
    if (!pcgActive(state)) { return; }
    float alpha = state[0].y;
    float step = alpha * direction.read(position).x;
    float stepError = fma(alpha, direction.read(position).x, -step);
    float2 q = pressureAdd(float2(pressure.read(position).x, pressureLow.read(position).x), step);
    q = pressureAdd(q, stepError);
    float r = residual.read(position).x - alpha * appliedDirection.read(position).x;
    pressure.write(q.x, position);
    pressureLow.write(q.y, position);
    residual.write(r, position);
}

kernel void fluid3DCheckRecursiveResidual(
    device float4 *state [[buffer(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0)) || !pcgActive(state)) { return; }
    float4 summary = state[10];
    state[15].w = 0.0f;
    if (summary.w < 1.0f || !all(isfinite(summary))) {
        state[16].y = 7.0f;
    // Recursive residuals are optimistic in Float32 on the full grid. Wait for
    // a one-decade margin before spending a reliable true-residual check; the
    // actual acceptance target remains state[17].z in CheckTrueResidual and
    // in the final divergence/residual gate.
    } else if (summary.z <= 0.1f * state[17].z) {
        state[15].w = 1.0f;
    }
}

kernel void fluid3DApplyACandidate(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *state [[buffer(1)]],
    texture3d<float, access::read> pressure [[texture(0)]],
    texture3d<float, access::write> output [[texture(1)]],
    texture3d<float, access::read> pressureLow [[texture(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth() || state[15].w != 1.0f) { return; }
    output.write(compensatedA(pressure, pressureLow, position, uniforms.grid.xyz), position);
}

kernel void fluid3DComputeCandidateResidual(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *state [[buffer(1)]],
    texture3d<float, access::read> rhs [[texture(0)]],
    texture3d<float, access::read> appliedPressure [[texture(1)]],
    texture3d<float, access::write> output [[texture(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= output.get_width() || position.y >= output.get_height()
        || position.z >= output.get_depth()) { return; }
    if (state[15].w != 1.0f) { output.write(0.0f, position); return; }
    output.write(rhs.read(position).x - appliedPressure.read(position).x, position);
}

kernel void fluid3DCheckTrueResidual(
    device float4 *state [[buffer(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0)) || !pcgActive(state) || state[15].w != 1.0f) { return; }
    float4 summary = state[11];
    if (summary.w < 1.0f || !all(isfinite(summary))) {
        state[16].y = 7.0f;
        state[15].w = 0.0f;
    } else if (summary.z <= state[17].z) {
        state[16].z = 1.0f;
        state[15].w = 0.0f;
    } else {
        state[17].w += 1.0f;
        if (state[17].w > 320.0f) {
            state[16].y = 9.0f;
            state[15].w = 0.0f;
        } else {
            state[15].w = 2.0f;
        }
    }
}

kernel void fluid3DCapturePCGTrace(
    device const float4 *state [[buffer(0)]],
    device float4 *trace [[buffer(1)]],
    constant uint &stage [[buffer(2)]],
    constant uint &encodedIteration [[buffer(3)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0))) { return; }
    uint iteration = uint(state[16].x);
    if (iteration == 0 || iteration > 320 || stage > 1 || iteration != encodedIteration) { return; }
    uint record = 2 * (iteration - 1) + stage;
    if (stage == 0) {
        trace[record] = float4(state[10].z, state[15].w, state[0].x, state[0].y);
    } else {
        bool checkedTrueResidual = trace[record - 1].y == 1.0f;
        trace[record] = float4(
            checkedTrueResidual ? state[11].z : -1.0f,
            state[15].w,
            state[16].y,
            state[0].w
        );
    }
}

kernel void fluid3DPrepareRestart(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *state [[buffer(1)]],
    texture3d<float, access::read> trueResidual [[texture(0)]],
    texture3d<float, access::write> residual [[texture(1)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= residual.get_width() || position.y >= residual.get_height()
        || position.z >= residual.get_depth()) { return; }
    if (state[15].w != 2.0f) { return; }
    uint count = uniforms.grid.x * uniforms.grid.y * uniforms.grid.z;
    residual.write(trueResidual.read(position).x - state[11].x / float(count), position);
}

kernel void fluid3DValidateNextRho(
    device float4 *state [[buffer(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0)) || !pcgActive(state) || state[15].w == 1.0f) { return; }
    float nextRho = state[6].x;
    float beta = 0.0f;
    if (!isfinite(nextRho) || nextRho <= 0.0f || state[6].w < 1.0f) {
        state[16].y = 8.0f;
        return;
    }
    if (state[15].w != 2.0f) {
        beta = nextRho / state[0].x;
        if (!isfinite(beta)) {
            state[16].y = 8.0f;
            return;
        }
    }
    state[0].z = beta;
}

kernel void fluid3DPCGUpdateDirection(
    device float4 *state [[buffer(0)]],
    texture3d<float, access::read> preconditioned [[texture(0)]],
    texture3d<float, access::read_write> direction [[texture(1)]],
    uint3 position [[thread_position_in_grid]]) {
    if (!pcgActive(state) || state[15].w == 1.0f) { return; }
    float z = preconditioned.read(position).x;
    float oldDirection = direction.read(position).x;
    direction.write(state[15].w == 2.0f ? z : z + state[0].z * oldDirection, position);
}

kernel void fluid3DFinalizePCGDirection(
    device float4 *state [[buffer(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0)) || !pcgActive(state) || state[15].w == 1.0f) { return; }
    state[0].x = state[6].x;
    state[15].w = 0.0f;
}

kernel void fluid3DProjectDirection(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *state [[buffer(1)]],
    texture3d<float, access::read_write> direction [[texture(0)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= direction.get_width() || position.y >= direction.get_height()
        || position.z >= direction.get_depth() || !pcgActive(state)) { return; }
    uint count = uniforms.grid.x * uniforms.grid.y * uniforms.grid.z;
    direction.write(direction.read(position).x - state[8].x / float(count), position);
}

kernel void fluid3DNormalizePressureGauge(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *state [[buffer(1)]],
    texture3d<float, access::read_write> pressure [[texture(0)]],
    texture3d<float, access::read_write> pressureLow [[texture(1)]],
    uint3 position [[thread_position_in_grid]]) {
    if (position.x >= pressure.get_width() || position.y >= pressure.get_height()
        || position.z >= pressure.get_depth()) { return; }
    if (state[8].w < 1.0f || state[16].y != 0.0f) { return; }
    uint count = uniforms.grid.x * uniforms.grid.y * uniforms.grid.z;
    float2 q = pressureAdd(float2(pressure.read(position).x, pressureLow.read(position).x),
        -state[8].x / float(count));
    pressure.write(q.x, position);
    pressureLow.write(q.y, position);
}

kernel void fluid3DFinalizeProjectionDiagnostics(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device float4 *state [[buffer(1)]],
    device uint *failureLatch [[buffer(2)]],
    uint3 position [[thread_position_in_grid]]) {
    if (any(position != uint3(0))) { return; }
    float4 divergence = state[12];
    float4 residual = state[11];
    float4 identity = state[13];
    float4 walls = state[5];
    if (divergence.w < 1.0f || residual.w < 1.0f || identity.w < 1.0f || walls.w < 1.0f
        || !all(isfinite(divergence)) || !all(isfinite(residual))
        || !all(isfinite(identity)) || !all(isfinite(walls))) {
        if (state[16].y == 0.0f) { state[16].y = 1.0f; }
        state[16].z = 0.0f;
        if (state[18].x != 0.0f) { failureLatch[0] = uint(state[16].y); }
        return;
    }
    float h = uniforms.scale.x;
    float dt = uniforms.scale.y;
    float projectedDT = dt * divergence.z;
    float residualDT = dt * residual.z / (h * h);
    float identityDT = dt * identity.z;
    float inputDT = state[14].z;
    float reduction = projectedDT > 0.0f ? inputDT / projectedDT
        : (inputDT > 0.0f ? 3.402823466e38f : 1.0f);
    state[15] = float4(projectedDT, residualDT, identityDT, reduction);
    bool accepted = projectedDT <= 1e-5f && residualDT <= 1e-5f
        && identityDT <= 2e-5f && walls.z == 0.0f
        && (inputDT < 1e-3f || reduction >= 1000.0f);
    if (state[16].y == 0.0f && accepted) {
        state[16].z = 1.0f;
        state[16].w = 0.0f;
    } else if (state[16].y == 0.0f) {
        state[16].z = 0.0f;
        if (state[16].x >= state[17].y) {
            state[16].y = 10.0f;
            state[16].w = 1.0f;
        } else {
            state[16].y = 11.0f;
        }
    }
    if (state[18].x != 0.0f && state[16].y != 0.0f) {
        failureLatch[0] = uint(state[16].y);
    }
}

kernel void fluid3DAdvectVelocityGuarded(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const uint *failureLatch [[buffer(1)]],
    texture3d<float, access::read> u [[texture(0)]],
    texture3d<float, access::read> v [[texture(1)]],
    texture3d<float, access::read> w [[texture(2)]],
    texture3d<float, access::read> input [[texture(3)]],
    texture3d<float, access::write> output [[texture(4)]],
    uint3 p [[thread_position_in_grid]]) {
    if (any(p >= uniforms.output.xyz)) { return; }
    if (failureLatch[0] != 0) { output.write(input.read(p).x, p); return; }
    uint component = uniforms.output.w;
    float3 target = outputPosition(p, component, uniforms.scale.x);
    float3 departure = backtraceRK2(u, v, w, target, uniforms);
    float3 offsets = component == 0 ? float3(0, .5f, .5f)
        : (component == 1 ? float3(.5f, 0, .5f) : float3(.5f, .5f, 0));
    output.write(sampleLattice(input, departure, offsets, uniforms.scale.x,
        float3(uniforms.grid.xyz), int(component)), p);
}

kernel void fluid3DAdvectDyeGuarded(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const uint *failureLatch [[buffer(1)]],
    texture3d<float, access::read> u [[texture(0)]],
    texture3d<float, access::read> v [[texture(1)]],
    texture3d<float, access::read> w [[texture(2)]],
    texture3d<float, access::read> input [[texture(3)]],
    texture3d<float, access::write> output [[texture(4)]],
    uint3 p [[thread_position_in_grid]]) {
    if (any(p >= uniforms.output.xyz)) { return; }
    if (failureLatch[0] != 0) { output.write(input.read(p).x, p); return; }
    float3 target = uniforms.scale.x * (float3(p) + .5f);
    float3 departure = backtraceRK2(u, v, w, target, uniforms);
    output.write(clamp(sampleLattice(input, departure, float3(.5f), uniforms.scale.x,
        float3(uniforms.grid.xyz), -1), 0.0f, 1.0f), p);
}

kernel void fluid3DRestoreFailedVelocity(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const uint *failureLatch [[buffer(1)]],
    texture3d<float, access::read> previous [[texture(0)]],
    texture3d<float, access::write> output [[texture(1)]],
    uint3 p [[thread_position_in_grid]]) {
    if (any(p >= uniforms.output.xyz) || failureLatch[0] == 0) { return; }
    output.write(previous.read(p).x, p);
}

kernel void fluid3DReduceField(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> input [[texture(0)]],
    device float4 *partials [[buffer(1)]],
    uint3 position [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 groupPosition [[threadgroup_position_in_grid]],
    uint3 groupWidth [[threads_per_threadgroup]]) {
    threadgroup float4 values[256];
    uint width = groupWidth.x;
    uint count = uniforms.output.x * uniforms.output.y * uniforms.output.z;
    float4 local = float4(0.0f, 0.0f, 0.0f, 1.0f);
    uint index = position.x;
    if (index < count) {
        uint x = index % uniforms.output.x;
        uint y = (index / uniforms.output.x) % uniforms.output.y;
        uint z = index / (uniforms.output.x * uniforms.output.y);
        float value = input.read(uint3(x, y, z)).x;
        if (isfinite(value)) {
            local.x = value;
            local.y = value * value;
            local.z = abs(value);
            if (!isfinite(local.y)) { local = float4(0.0f); }
        } else {
            local.w = 0.0f;
        }
    }
    values[lane] = local;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = width / 2; stride > 0; stride >>= 1) {
        if (lane < stride) { values[lane] = reducePair(values[lane], values[lane + stride]); }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) { partials[groupPosition.x] = values[0]; }
}

kernel void fluid3DReduceWallFlux(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    texture3d<float, access::read> u [[texture(0)]],
    texture3d<float, access::read> v [[texture(1)]],
    texture3d<float, access::read> w [[texture(2)]],
    device float4 *partials [[buffer(1)]],
    uint3 position [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 groupPosition [[threadgroup_position_in_grid]],
    uint3 groupWidth [[threads_per_threadgroup]]) {
    threadgroup float4 values[256];
    uint nx = uniforms.grid.x;
    uint ny = uniforms.grid.y;
    uint nz = uniforms.grid.z;
    uint countX = ny * nz;
    uint countY = nx * nz;
    uint countZ = nx * ny;
    uint width = groupWidth.x;
    uint index = position.x;
    float4 local = float4(0.0f, 0.0f, 0.0f, 1.0f);
    if (index < uniforms.grid.w) {
        float signedVelocity = 0.0f;
        if (index < 2 * countX) {
            uint side = index / countX;
            uint cell = index % countX;
            uint j = cell % ny;
            uint k = cell / ny;
            float value = u.read(uint3(side == 0 ? 0 : nx, j, k)).x;
            signedVelocity = side == 0 ? -value : value;
        } else if (index < 2 * countX + 2 * countY) {
            uint localIndex = index - 2 * countX;
            uint side = localIndex / countY;
            uint cell = localIndex % countY;
            uint i = cell % nx;
            uint k = cell / nx;
            float value = v.read(uint3(i, side == 0 ? 0 : ny, k)).x;
            signedVelocity = side == 0 ? -value : value;
        } else {
            uint localIndex = index - 2 * countX - 2 * countY;
            uint side = localIndex / countZ;
            uint cell = localIndex % countZ;
            uint i = cell % nx;
            uint j = cell / nx;
            float value = w.read(uint3(i, j, side == 0 ? 0 : nz)).x;
            signedVelocity = side == 0 ? -value : value;
        }
        if (isfinite(signedVelocity)) {
            local = float4(signedVelocity, signedVelocity * signedVelocity, abs(signedVelocity), 1.0f);
            if (!isfinite(local.y)) { local = float4(0.0f); }
        } else {
            local.w = 0.0f;
        }
    }
    values[lane] = local;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = width / 2; stride > 0; stride >>= 1) {
        if (lane < stride) { values[lane] = reducePair(values[lane], values[lane + stride]); }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) { partials[groupPosition.x] = values[0]; }
}

kernel void fluid3DFinalizeReduction(
    constant Fluid3DUniforms &uniforms [[buffer(0)]],
    device const float4 *partials [[buffer(1)]],
    device float4 *result [[buffer(2)]],
    uint lane [[thread_index_in_threadgroup]],
    uint3 groupWidth [[threads_per_threadgroup]]) {
    threadgroup float4 values[256];
    uint width = groupWidth.x;
    float4 local = float4(0.0f, 0.0f, 0.0f, 1.0f);
    for (uint index = lane; index < uniforms.grid.x; index += width) {
        float4 partial = partials[index];
        if (all(isfinite(partial))) {
            local = reducePair(local, partial);
        } else {
            local.w = 0.0f;
        }
    }
    if (!isfinite(local.x) || !isfinite(local.y) || !isfinite(local.z)) {
        local = float4(0.0f);
    }
    values[lane] = local;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = width / 2; stride > 0; stride >>= 1) {
        if (lane < stride) { values[lane] = reducePair(values[lane], values[lane + stride]); }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) { result[0] = values[0]; }
}

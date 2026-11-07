#include <metal_stdlib>
using namespace metal;

// Must match Fluid3DUniforms exactly: 3 x 16-byte Swift/Metal lanes.
struct Fluid3DUniforms {
    uint4 grid;
    float4 scale;
    uint4 output;
};

kernel void fluid3DABIRoundTrip(
    constant Fluid3DUniforms &input [[buffer(0)]],
    device Fluid3DUniforms *output [[buffer(1)]],
    uint threadIndex [[thread_position_in_grid]]) {
    if (threadIndex != 0) {
        return;
    }
    output[0] = input;
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

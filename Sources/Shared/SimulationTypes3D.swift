import Foundation
import Metal
import simd

enum FluidSimulation3DError: Error, LocalizedError {
    case invalidConfiguration(String)
    case pipelineCreationFailed(function: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let detail): "Invalid 3D fluid configuration: \(detail)"
        case .pipelineCreationFailed(let function, let reason):
            "Unable to create 3D compute pipeline '\(function)': \(reason)"
        }
    }
}

/// Grid and dimensionless step parameters for the separate 3D solver.
/// Production construction is intentionally fixed at 64 cubed; smaller grids
/// are available only through the explicitly named fixture factory.
struct FluidSimulation3DConfiguration: Equatable {
    let nx: Int
    let ny: Int
    let nz: Int
    let h: Float
    let dt: Float
    let isProduction: Bool

    static let production = FluidSimulation3DConfiguration(
        uncheckedNX: 64,
        ny: 64,
        nz: 64,
        h: 1.0 / 64.0,
        dt: 1.0 / 60.0,
        isProduction: true
    )

    private init(uncheckedNX nx: Int, ny: Int, nz: Int, h: Float, dt: Float, isProduction: Bool) {
        self.nx = nx
        self.ny = ny
        self.nz = nz
        self.h = h
        self.dt = dt
        self.isProduction = isProduction
    }

    static func fixture(
        nx: Int,
        ny: Int,
        nz: Int,
        h: Float = 1,
        dt: Float = 1.0 / 60.0
    ) throws -> FluidSimulation3DConfiguration {
        guard (1...64).contains(nx), (1...64).contains(ny), (1...64).contains(nz) else {
            throw FluidSimulation3DError.invalidConfiguration(
                "fixture dimensions must each be in 1...64 (received \(nx)x\(ny)x\(nz))"
            )
        }
        guard h.isFinite, h > 0 else {
            throw FluidSimulation3DError.invalidConfiguration("grid spacing must be finite and positive")
        }
        let inverseSpacing = 1 / h
        let maximumExtent = Float(max(nx, max(ny, nz))) * h
        guard inverseSpacing.isFinite, inverseSpacing > 0,
              maximumExtent.isFinite, maximumExtent > 0 else {
            throw FluidSimulation3DError.invalidConfiguration(
                "grid spacing must produce finite positive inverse spacing and domain extents"
            )
        }
        guard dt.isFinite, dt > 0 else {
            throw FluidSimulation3DError.invalidConfiguration("time step must be finite and positive")
        }
        return FluidSimulation3DConfiguration(
            uncheckedNX: nx,
            ny: ny,
            nz: nz,
            h: h,
            dt: dt,
            isProduction: false
        )
    }
}

/// Cross-language contract for the first 3D Metal kernels. Keep these three
/// 16-byte lanes independent from the established 2D StaticData/BufferData ABI.
struct Fluid3DUniforms: Equatable {
    var grid: SIMD4<UInt32>
    var scale: SIMD4<Float>
    var output: SIMD4<UInt32>

    static var abiIsValid: Bool {
        MemoryLayout<Self>.stride == 48
            && MemoryLayout<Self>.alignment == 16
            && MemoryLayout<Self>.offset(of: \.grid) == 0
            && MemoryLayout<Self>.offset(of: \.scale) == 16
            && MemoryLayout<Self>.offset(of: \.output) == 32
            && MemoryLayout<SIMD4<UInt32>>.stride == 16
            && MemoryLayout<SIMD4<Float>>.stride == 16
    }
}

enum Fluid3DDispatch {
    /// Use a 1D threadgroup whose width is legal for this exact pipeline. The
    /// 3D grid is still dispatched by Metal across all texture dimensions.
    static func threadsPerThreadgroup(for pipeline: MTLComputePipelineState) -> MTLSize {
        let limit = max(1, pipeline.maxTotalThreadsPerThreadgroup)
        let preferredWidth = max(1, pipeline.threadExecutionWidth)
        return MTLSize(width: min(limit, preferredWidth), height: 1, depth: 1)
    }
}

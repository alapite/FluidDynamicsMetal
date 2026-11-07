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

enum Fluid3DProjectionFailure: UInt32, Error, CaseIterable, CustomStringConvertible {
    case none = 0
    case nonfiniteInput = 1
    case incompatibleRHS = 2
    case nonzeroWallNormal = 3
    case invalidInitialPreconditionedResidual = 4
    case invalidSearchDenominator = 5
    case nonfiniteAlpha = 6
    case nonfiniteIterate = 7
    case invalidPreconditionedResidual = 8
    case trueResidualRestartExhausted = 9
    case iterationCapExceeded = 10
    case finalAcceptanceFailed = 11
    case priorSessionFailure = 12

    var description: String {
        switch self {
        case .none: "none"
        case .nonfiniteInput: "nonfinite input or reduction"
        case .incompatibleRHS: "closed-box RHS compatibility mean exceeds roundoff bound"
        case .nonzeroWallNormal: "input has nonzero wall-normal velocity"
        case .invalidInitialPreconditionedResidual: "initial preconditioned residual is nonpositive or nonfinite"
        case .invalidSearchDenominator: "PCG search denominator is nonpositive or nonfinite"
        case .nonfiniteAlpha: "PCG alpha is nonfinite"
        case .nonfiniteIterate: "PCG iterate or recursive residual is nonfinite"
        case .invalidPreconditionedResidual: "preconditioned residual is nonpositive or nonfinite"
        case .trueResidualRestartExhausted: "true-residual restart limit exhausted"
        case .iterationCapExceeded: "iteration cap reached before true-residual tolerance"
        case .finalAcceptanceFailed: "final divergence, residual, identity, or wall acceptance failed"
        case .priorSessionFailure: "a prior queued submission failed; reset is required"
        }
    }
}

/// Fixture-only fault injection for validating guarded PCG failure reporting.
/// Production configurations reject every non-`.none` case.
enum Fluid3DProjectionFailureInjection: UInt32 {
    case none = 0
    case zeroSearchDenominator = 1
    case negativeSearchDenominator = 2
    case nonfiniteSearchDenominator = 3
}

/// ABI shared by Swift and Metal for one queued projection submission. Every
/// lane is a float4; lane indices are documented in `PressureProjection3D` and
/// must stay aligned with the `Fluid3DPCGState` declaration in Shaders3D.metal.
struct Fluid3DPCGState {
    var recurrence = SIMD4<Float>(repeating: 0)                 // 0: rho, alpha, beta, denominator
    var rhsSummary = SIMD4<Float>(repeating: 0)                 // 1: sum, sumSquares, maxAbs, allFinite
    var uSummary = SIMD4<Float>(repeating: 0)                   // 2
    var vSummary = SIMD4<Float>(repeating: 0)                   // 3
    var wSummary = SIMD4<Float>(repeating: 0)                   // 4
    var wallSummary = SIMD4<Float>(repeating: 0)                // 5: signed flux, squares, maxAbs, allFinite
    var dotSummary = SIMD4<Float>(repeating: 0)                 // 6
    var preconditionerMean = SIMD4<Float>(repeating: 0)         // 7
    var pressureMean = SIMD4<Float>(repeating: 0)               // 8
    var residualMean = SIMD4<Float>(repeating: 0)                // 9
    var recursiveResidualSummary = SIMD4<Float>(repeating: 0)   // 10
    var trueResidualSummary = SIMD4<Float>(repeating: 0)        // 11
    var projectedDivergenceSummary = SIMD4<Float>(repeating: 0) // 12
    var identityErrorSummary = SIMD4<Float>(repeating: 0)       // 13
    var inputMetrics = SIMD4<Float>(repeating: 0)               // 14: b mean, compatibility bound, input dt*divInf, max|u*|
    var outputMetrics = SIMD4<Float>(repeating: 0)              // 15: projected dt*divInf, true residual dt norm, dt identity, div reduction
    var control = SIMD4<Float>(repeating: 0)                    // 16: iterations, failure code, converged, capHit
    var options = SIMD4<Float>(repeating: 0)                    // 17: test injection, iteration limit, target, restart count
    var session = SIMD4<Float>(repeating: 0)                    // 18: uses shared failure latch

    static let laneCount = 19

    static var abiIsValid: Bool {
        MemoryLayout<Self>.stride == laneCount * MemoryLayout<SIMD4<Float>>.stride
            && MemoryLayout<Self>.alignment == MemoryLayout<SIMD4<Float>>.alignment
            && MemoryLayout<Self>.offset(of: \.recurrence) == 0
            && MemoryLayout<Self>.offset(of: \.rhsSummary) == 16
            && MemoryLayout<Self>.offset(of: \.uSummary) == 32
            && MemoryLayout<Self>.offset(of: \.options) == 17 * 16
            && MemoryLayout<Self>.offset(of: \.session) == 18 * 16
    }
}

struct Fluid3DProjectionDiagnostics {
    let iterations: Int
    let trueResidualRestarts: Int
    let recursiveResidualMax: Float
    let finalPreconditionedResidualDot: Float
    let finalAlpha: Float
    let finalBeta: Float
    let finalSearchDenominator: Float
    let failure: Fluid3DProjectionFailure
    let converged: Bool
    let capHit: Bool
    let rhsMean: Float
    let compatibilityBound: Float
    let inputDivergenceDTInf: Float
    let projectedDivergenceDTInf: Float
    let trueResidualDTInf: Float
    let identityDTError: Float
    let divergenceReduction: Float
    let maximumWallNormalValue: Float
}

struct Fluid3DPCGTraceRecord {
    let iteration: Int
    let recursiveResidualMaximum: Float
    let checkedTrueResidual: Bool
    let rho: Float
    let alpha: Float
    let trueResidualMaximum: Float?
    let restartPending: Bool
    let failureCode: Float
    let searchDenominator: Float
}

/// Explicit deterministic reset payload. Recipe selection belongs to the next
/// plan; this encoder accepts a complete initial state without view dependencies.
struct Fluid3DInitialState {
    let u: [Float]
    let v: [Float]
    let w: [Float]
    let dye: [Float]
}

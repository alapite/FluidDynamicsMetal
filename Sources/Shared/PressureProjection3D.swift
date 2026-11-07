import Foundation
import Metal

enum PressureProjection3DError: Error, LocalizedError {
    case pipelineCreationFailed(function: String, reason: String)
    case encoderUnavailable(operation: String)
    case reductionWorkspaceAllocationFailed(byteCount: Int)
    case reductionResultAllocationFailed(label: String)
    case invalidTexture(resource: String, expected: String)
    case reductionCapacityExceeded(required: Int, available: Int)

    var errorDescription: String? {
        switch self {
        case .pipelineCreationFailed(let function, let reason):
            "Unable to create 3D pressure pipeline '\(function)': \(reason)"
        case .encoderUnavailable(let operation):
            "Unable to create Metal encoder for 3D pressure operation: \(operation)"
        case .reductionWorkspaceAllocationFailed(let byteCount):
            "Unable to allocate \(byteCount)-byte 3D reduction workspace"
        case .reductionResultAllocationFailed(let label):
            "Unable to allocate 3D reduction result buffer for \(label)"
        case .invalidTexture(let resource, let expected):
            "Invalid 3D pressure texture '\(resource)'; expected \(expected)"
        case .reductionCapacityExceeded(let required, let available):
            "3D reduction requires \(required) partials; workspace holds \(available)"
        }
    }
}

/// Production compatible MAC operators and GPU-side diagnostics.
///
/// The object owns pressure and scalar scratch textures but never waits for a
/// command buffer or reads GPU state back. Callers serialize writes to these
/// resources on their command queue. Reduction partials and scalar outputs are
/// separate resources so each cross-threadgroup dependency is an explicit pass.
@MainActor
final class PressureProjection3D {
    static let maximumIterations = 320

    /// One GPU status allocation per queued projection. Keep a slot distinct
    /// until its command buffer completes; renderers can rotate three slots for
    /// three in-flight submissions without diagnostics being overwritten.
    final class StatusSlot {
        fileprivate let buffer: MTLBuffer
        fileprivate let deviceRegistryID: UInt64
        fileprivate let pcgTraceBuffer: MTLBuffer?

        fileprivate init(buffer: MTLBuffer, deviceRegistryID: UInt64, pcgTraceBuffer: MTLBuffer?) {
            self.buffer = buffer
            self.deviceRegistryID = deviceRegistryID
            self.pcgTraceBuffer = pcgTraceBuffer
        }

        /// Call only after the owning command buffer has completed.
        func diagnosticStateValues() -> [Float] {
            let values = buffer.contents().assumingMemoryBound(to: Float.self)
            return Array(UnsafeBufferPointer(start: values, count: buffer.length / MemoryLayout<Float>.stride))
        }

        /// Call only after the owning command buffer has completed.
        func diagnostics() -> Fluid3DProjectionDiagnostics {
            let state = buffer.contents().assumingMemoryBound(to: Fluid3DPCGState.self).pointee
            let code = UInt32(max(0, state.control.y.rounded()))
            return Fluid3DProjectionDiagnostics(
                iterations: Int(max(0, state.control.x.rounded())),
                trueResidualRestarts: Int(max(0, state.options.w.rounded())),
                recursiveResidualMax: state.recursiveResidualSummary.z,
                finalPreconditionedResidualDot: state.dotSummary.x,
                finalAlpha: state.recurrence.y,
                finalBeta: state.recurrence.z,
                finalSearchDenominator: state.recurrence.w,
                failure: Fluid3DProjectionFailure(rawValue: code) ?? .finalAcceptanceFailed,
                converged: state.control.z == 1,
                capHit: state.control.w == 1,
                rhsMean: state.inputMetrics.x,
                compatibilityBound: state.inputMetrics.y,
                inputDivergenceDTInf: state.inputMetrics.z,
                projectedDivergenceDTInf: state.outputMetrics.x,
                trueResidualDTInf: state.outputMetrics.y,
                identityDTError: state.outputMetrics.z,
                divergenceReduction: state.outputMetrics.w,
                maximumWallNormalValue: state.wallSummary.z
            )
        }

        @MainActor func pcgTrace(iterations: Int) -> [Fluid3DPCGTraceRecord]? {
            guard let pcgTraceBuffer else { return nil }
            let count = min(max(iterations, 0), PressureProjection3D.maximumIterations)
            let values = pcgTraceBuffer.contents().assumingMemoryBound(to: SIMD4<Float>.self)
            return (0..<count).map { iteration in
                let recursive = values[2 * iteration]
                let trueResidual = values[2 * iteration + 1]
                let checkedTrueResidual = recursive.y == 1
                return Fluid3DPCGTraceRecord(
                    iteration: iteration + 1,
                    recursiveResidualMaximum: recursive.x,
                    checkedTrueResidual: checkedTrueResidual,
                    rho: recursive.z,
                    alpha: recursive.w,
                    trueResidualMaximum: checkedTrueResidual ? trueResidual.x : nil,
                    restartPending: trueResidual.y == 2,
                    failureCode: trueResidual.z,
                    searchDenominator: trueResidual.w
                )
            }
        }
    }

    let metal: MetalDevice
    let configuration: FluidSimulation3DConfiguration

    let pressure: VolumeField3D
    let divergence: VolumeField3D
    let rhs: VolumeField3D
    let appliedOperator: VolumeField3D
    let trueResidual: VolumeField3D
    let identityError: VolumeField3D
    let recursiveResidual: VolumeField3D
    let preconditioned: VolumeField3D
    let searchDirection: VolumeField3D

    private let divergencePipeline: MTLComputePipelineState
    private let applyAPipeline: MTLComputePipelineState
    private let applyACompensatedPipeline: MTLComputePipelineState
    private let subtractCompensatedGradientPipeline: MTLComputePipelineState
    private let subtractGradientPipeline: MTLComputePipelineState
    private let rhsPipeline: MTLComputePipelineState
    private let residualPipeline: MTLComputePipelineState
    private let identityPipeline: MTLComputePipelineState
    private let reduceFieldPipeline: MTLComputePipelineState
    private let reduceDotPipeline: MTLComputePipelineState
    private let reducePCGStatePipeline: MTLComputePipelineState
    private let reduceWallFluxPipeline: MTLComputePipelineState
    private let finalizeReductionPipeline: MTLComputePipelineState
    private let initializeSolverStatePipeline: MTLComputePipelineState
    private let initializeProjectionStatusPipeline: MTLComputePipelineState
    private let initializePCGFieldsPipeline: MTLComputePipelineState
    private let projectPressureResidualPipeline: MTLComputePipelineState
    private let preconditionVectorPipeline: MTLComputePipelineState
    private let projectPreconditionerPipeline: MTLComputePipelineState
    private let initializeRhoPipeline: MTLComputePipelineState
    private let applySearchPipeline: MTLComputePipelineState
    private let updatePCGPipeline: MTLComputePipelineState
    private let preparePCGUpdatePipeline: MTLComputePipelineState
    private let validateSummaryPipeline: MTLComputePipelineState
    private let checkRecursiveResidualPipeline: MTLComputePipelineState
    private let applyCandidatePipeline: MTLComputePipelineState
    private let computeCandidateResidualPipeline: MTLComputePipelineState
    private let checkTrueResidualPipeline: MTLComputePipelineState
    private let prepareRestartPipeline: MTLComputePipelineState
    private let validateNextRhoPipeline: MTLComputePipelineState
    private let updateDirectionPipeline: MTLComputePipelineState
    private let finalizePCGDirectionPipeline: MTLComputePipelineState
    private let projectDirectionPipeline: MTLComputePipelineState
    private let normalizePressureGaugePipeline: MTLComputePipelineState
    private let finalizeProjectionDiagnosticsPipeline: MTLComputePipelineState
    private let capturePCGTracePipeline: MTLComputePipelineState
    private let enforceWallsPipeline: MTLComputePipelineState
    private let reductionPartials: MTLBuffer
    private let reductionGroupSize: MTLSize
    private let finalReductionGroupSize: MTLSize
    private let reductionPartialCapacity: Int
    private let standaloneLatch: MTLBuffer

    private enum StateLane: Int {
        case recurrence = 0
        case rhsSummary = 1
        case uSummary = 2
        case vSummary = 3
        case wSummary = 4
        case wallSummary = 5
        case dotSummary = 6
        case preconditionerMean = 7
        case pressureMean = 8
        case residualMean = 9
        case recursiveResidualSummary = 10
        case trueResidualSummary = 11
        case projectedDivergenceSummary = 12
        case identityErrorSummary = 13
        case inputMetrics = 14
        case outputMetrics = 15
        case control = 16
        case options = 17

        var byteOffset: Int { rawValue * MemoryLayout<SIMD4<Float>>.stride }
    }

    init(metal: MetalDevice, configuration: FluidSimulation3DConfiguration) throws {
        self.metal = metal
        self.configuration = configuration

        pressure = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        divergence = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        rhs = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        appliedOperator = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        trueResidual = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        identityError = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        recursiveResidual = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        preconditioned = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        searchDirection = try VolumeField3D(grid: configuration, component: .cell, metal: metal)

        divergencePipeline = try Self.makePipeline("fluid3DDivergence", metal: metal)
        applyAPipeline = try Self.makePipeline("fluid3DApplyA", metal: metal)
        applyACompensatedPipeline = try Self.makePipeline("fluid3DApplyACompensated", metal: metal)
        subtractCompensatedGradientPipeline = try Self.makePipeline("fluid3DSubtractGradientCompensated", metal: metal)
        subtractGradientPipeline = try Self.makePipeline("fluid3DSubtractGradient", metal: metal)
        rhsPipeline = try Self.makePipeline("fluid3DComputeRHS", metal: metal)
        residualPipeline = try Self.makePipeline("fluid3DComputeResidual", metal: metal)
        identityPipeline = try Self.makePipeline("fluid3DIdentityError", metal: metal)
        reduceFieldPipeline = try Self.makePipeline("fluid3DReduceField", metal: metal)
        reduceDotPipeline = try Self.makePipeline("fluid3DReduceDot", metal: metal)
        reducePCGStatePipeline = try Self.makePipeline("fluid3DReducePCGState", metal: metal)
        reduceWallFluxPipeline = try Self.makePipeline("fluid3DReduceWallFlux", metal: metal)
        finalizeReductionPipeline = try Self.makePipeline("fluid3DFinalizeReduction", metal: metal)
        initializeSolverStatePipeline = try Self.makePipeline("fluid3DInitializeSolverState", metal: metal)
        initializeProjectionStatusPipeline = try Self.makePipeline("fluid3DInitializeProjectionStatus", metal: metal)
        initializePCGFieldsPipeline = try Self.makePipeline("fluid3DInitializePCGFields", metal: metal)
        projectPressureResidualPipeline = try Self.makePipeline("fluid3DProjectPressureResidual", metal: metal)
        preconditionVectorPipeline = try Self.makePipeline("fluid3DPreconditionVector", metal: metal)
        projectPreconditionerPipeline = try Self.makePipeline("fluid3DProjectPreconditioner", metal: metal)
        initializeRhoPipeline = try Self.makePipeline("fluid3DInitializeRho", metal: metal)
        applySearchPipeline = try Self.makePipeline("fluid3DApplyASearch", metal: metal)
        updatePCGPipeline = try Self.makePipeline("fluid3DPCGUpdate", metal: metal)
        preparePCGUpdatePipeline = try Self.makePipeline("fluid3DPreparePCGUpdate", metal: metal)
        validateSummaryPipeline = try Self.makePipeline("fluid3DValidateSummary", metal: metal)
        checkRecursiveResidualPipeline = try Self.makePipeline("fluid3DCheckRecursiveResidual", metal: metal)
        applyCandidatePipeline = try Self.makePipeline("fluid3DApplyACandidate", metal: metal)
        computeCandidateResidualPipeline = try Self.makePipeline("fluid3DComputeCandidateResidual", metal: metal)
        checkTrueResidualPipeline = try Self.makePipeline("fluid3DCheckTrueResidual", metal: metal)
        prepareRestartPipeline = try Self.makePipeline("fluid3DPrepareRestart", metal: metal)
        validateNextRhoPipeline = try Self.makePipeline("fluid3DValidateNextRho", metal: metal)
        updateDirectionPipeline = try Self.makePipeline("fluid3DPCGUpdateDirection", metal: metal)
        finalizePCGDirectionPipeline = try Self.makePipeline("fluid3DFinalizePCGDirection", metal: metal)
        projectDirectionPipeline = try Self.makePipeline("fluid3DProjectDirection", metal: metal)
        normalizePressureGaugePipeline = try Self.makePipeline("fluid3DNormalizePressureGauge", metal: metal)
        finalizeProjectionDiagnosticsPipeline = try Self.makePipeline("fluid3DFinalizeProjectionDiagnostics", metal: metal)
        capturePCGTracePipeline = try Self.makePipeline("fluid3DCapturePCGTrace", metal: metal)
        enforceWallsPipeline = try Self.makePipeline("fluid3DEnforceWalls", metal: metal)

        let partialWidth = min(256, reduceFieldPipeline.maxTotalThreadsPerThreadgroup)
        reductionGroupSize = MTLSize(width: partialWidth, height: 1, depth: 1)
        let finalWidth = min(256, finalizeReductionPipeline.maxTotalThreadsPerThreadgroup)
        finalReductionGroupSize = MTLSize(width: finalWidth, height: 1, depth: 1)
        let maxCells = try Self.checkedProduct(configuration.nx, configuration.ny, configuration.nz)
        let wallCount = try Self.checkedWallFaceCount(configuration)
        let maximumFaceValues = try [VolumeField3D.Component.u, .v, .w].map { component in
            let extent = component.dimensions(for: configuration)
            return try Self.checkedProduct(extent.width, extent.height, extent.depth)
        }.max() ?? maxCells
        let maximumValues = max(maxCells, max(wallCount, maximumFaceValues))
        let roundedCount = maximumValues.addingReportingOverflow(reductionGroupSize.width - 1)
        guard !roundedCount.overflow else {
            throw PressureProjection3DError.reductionWorkspaceAllocationFailed(byteCount: Int.max)
        }
        reductionPartialCapacity = roundedCount.partialValue / reductionGroupSize.width
        let byteCount = reductionPartialCapacity.multipliedReportingOverflow(
            by: MemoryLayout<SIMD4<Float>>.stride
        )
        guard !byteCount.overflow,
              let partials = metal.device.makeBuffer(
                length: byteCount.partialValue,
                options: .storageModePrivate
              ) else {
            throw PressureProjection3DError.reductionWorkspaceAllocationFailed(
                byteCount: byteCount.overflow ? Int.max : byteCount.partialValue
            )
        }
        partials.label = "3D pressure reduction partials"
        reductionPartials = partials
        guard let latch = metal.device.makeBuffer(length: 4, options: .storageModeShared) else {
            throw PressureProjection3DError.reductionResultAllocationFailed(label: "standalone latch")
        }
        latch.contents().storeBytes(of: UInt32(0), as: UInt32.self)
        standaloneLatch = latch
    }

    /// Encodes D(u) on every cell, including all six boundary-adjacent slabs.
    func encodeDivergence(
        command: MTLCommandBuffer,
        u: MTLTexture,
        v: MTLTexture,
        w: MTLTexture,
        output: MTLTexture
    ) throws {
        try validateCellTexture(output, resource: "divergence output")
        try validateFaceTextures(u: u, v: v, w: w)
        try encode(
            divergencePipeline,
            command: command,
            operation: "MAC divergence",
            output: output,
            textures: [u, v, w, output]
        )
    }

    /// Encodes A(q) = -h²DG(q) using the equivalent compatible neighbour
    /// stencil. Its degree is the number of interior faces at that cell.
    func encodeApplyA(
        command: MTLCommandBuffer,
        pressure: MTLTexture,
        output: MTLTexture
    ) throws {
        try validateCellTexture(pressure, resource: "pressure input")
        try validateCellTexture(output, resource: "operator output")
        try encode(
            applyAPipeline,
            command: command,
            operation: "compatible pressure operator",
            output: output,
            textures: [pressure, output]
        )
    }

    /// Encodes one component of u - Gq. Exterior wall-normal gradients are
    /// exactly zero, so valid wall values pass through unchanged.
    func encodeSubtractGradient(
        command: MTLCommandBuffer,
        pressure: MTLTexture,
        input: MTLTexture,
        output: MTLTexture,
        component: VolumeField3D.Component
    ) throws {
        try validateCellTexture(pressure, resource: "pressure input")
        guard component != .cell else {
            throw PressureProjection3DError.invalidTexture(
                resource: "velocity component", expected: "u, v, or w face layout"
            )
        }
        try validateFaceTexture(input, component: component, resource: "velocity input")
        try validateFaceTexture(output, component: component, resource: "velocity output")
        try encode(
            subtractGradientPipeline,
            command: command,
            operation: "subtract \(component.rawValue) pressure gradient",
            output: output,
            componentID: Self.componentID(component),
            textures: [pressure, input, output]
        )
    }

    /// Forms b=-h²D(u*) in q-operator units.
    func encodeRHS(command: MTLCommandBuffer, divergence: MTLTexture, output: MTLTexture) throws {
        try validateCellTexture(divergence, resource: "RHS divergence input")
        try validateCellTexture(output, resource: "RHS output")
        try encode(
            rhsPipeline,
            command: command,
            operation: "pressure right-hand side",
            output: output,
            textures: [divergence, output]
        )
    }

    /// Recomputes the true residual r=b-Aq from the original divergence and A(q).
    func encodeTrueResidual(
        command: MTLCommandBuffer,
        divergence: MTLTexture,
        appliedOperator: MTLTexture,
        output: MTLTexture
    ) throws {
        try validateCellTexture(divergence, resource: "true-residual divergence input")
        try validateCellTexture(appliedOperator, resource: "true-residual A(q) input")
        try validateCellTexture(output, resource: "true-residual output")
        try encode(
            residualPipeline,
            command: command,
            operation: "recompute true pressure residual",
            output: output,
            textures: [divergence, appliedOperator, output]
        )
    }

    /// Encodes D(uNew)+r/h²; its maximum magnitude measures the compatible
    /// operator identity independently of pressure-gauge choice.
    func encodeIdentityError(
        command: MTLCommandBuffer,
        projectedDivergence: MTLTexture,
        trueResidual: MTLTexture,
        output: MTLTexture
    ) throws {
        try validateCellTexture(projectedDivergence, resource: "identity divergence input")
        try validateCellTexture(trueResidual, resource: "identity residual input")
        try validateCellTexture(output, resource: "identity output")
        try encode(
            identityPipeline,
            command: command,
            operation: "pressure/divergence identity diagnostic",
            output: output,
            textures: [projectedDivergence, trueResidual, output]
        )
    }

    /// Writes [sum, sumSquares, maxAbs, allFinite] to a caller-owned result
    /// buffer. Partial and final reductions use distinct ordered encoders.
    func encodeReduction(
        command: MTLCommandBuffer,
        input: MTLTexture,
        result: MTLBuffer,
        resultOffset: Int = 0
    ) throws {
        try encodeReductionPass(
            command: command,
            primary: input,
            secondary: nil,
            pipeline: reduceFieldPipeline,
            operation: "scalar field reduction",
            result: result,
            resultOffset: resultOffset
        )
    }

    /// Reduces the six wall planes as outward signed face flux. The result's
    /// sum is the net velocity flux across all faces; multiply by h² for area.
    func encodeWallFluxReduction(
        command: MTLCommandBuffer,
        u: MTLTexture,
        v: MTLTexture,
        w: MTLTexture,
        result: MTLBuffer,
        resultOffset: Int = 0
    ) throws {
        try validateFaceTextures(u: u, v: v, w: w)
        try validateReductionResult(result, offset: resultOffset)
        let faceCount = try Self.checkedWallFaceCount(configuration)
        let groupCount = try groupCount(for: faceCount)
        var uniforms = makeUniforms(output: divergence.ping)
        uniforms.grid.w = UInt32(faceCount)
        try encodePartialReduction(
            command: command,
            uniforms: &uniforms,
            pipeline: reduceWallFluxPipeline,
            operation: "six-face wall-flux reduction",
            textures: [u, v, w],
            groupCount: groupCount
        )
        try encodeFinalReduction(
            command: command,
            groupCount: groupCount,
            result: result,
            resultOffset: resultOffset,
            uniforms: uniforms
        )
    }

    private func encodeDotReduction(
        command: MTLCommandBuffer,
        left: MTLTexture,
        right: MTLTexture,
        status: StatusSlot,
        resultLane: StateLane
    ) throws {
        try encodeReductionPass(
            command: command,
            primary: left,
            secondary: right,
            pipeline: reduceDotPipeline,
            operation: "PCG dot product",
            result: status.buffer,
            resultOffset: resultLane.byteOffset
        )
    }

    private func encodePCGStateReduction(command: MTLCommandBuffer, status: StatusSlot) throws {
        try encodeReductionPass(
            command: command,
            primary: pressure.ping,
            secondary: recursiveResidual.ping,
            pipeline: reducePCGStatePipeline,
            operation: "PCG pressure/residual projection",
            result: status.buffer,
            resultOffset: StateLane.pressureMean.byteOffset
        )
        try encodeValidateSummary(command: command, status: status, lane: .pressureMean, failure: .nonfiniteIterate)
    }

    private func encodeValidateSummary(
        command: MTLCommandBuffer, status: StatusSlot, lane: StateLane, failure: Fluid3DProjectionFailure
    ) throws {
        var uniforms = makeUniforms(output: pressure.ping)
        uniforms.output.w = UInt32(lane.rawValue)
        uniforms.output.z = failure.rawValue
        try encodeStateKernel(validateSummaryPipeline, command: command, operation: "validate reduced scalar state",
                              status: status, uniforms: uniforms, textures: [],
                              extent: MTLSize(width: 1, height: 1, depth: 1))
    }

    private func encodeReductionPass(
        command: MTLCommandBuffer,
        primary: MTLTexture,
        secondary: MTLTexture?,
        pipeline: MTLComputePipelineState,
        operation: String,
        result: MTLBuffer,
        resultOffset: Int
    ) throws {
        try validateReductionTexture(primary, resource: "\(operation) input")
        if let secondary {
            try validateReductionTexture(secondary, resource: "\(operation) secondary input")
            guard primary.width == secondary.width, primary.height == secondary.height,
                  primary.depth == secondary.depth else {
                throw PressureProjection3DError.invalidTexture(
                    resource: "\(operation) secondary input",
                    expected: "the same extent as the primary input"
                )
            }
        }
        try validateReductionResult(result, offset: resultOffset)
        let count = try Self.checkedProduct(primary.width, primary.height, primary.depth)
        let groupCount = try groupCount(for: count)
        var uniforms = makeUniforms(output: primary)
        var textures = [primary]
        if let secondary { textures.append(secondary) }
        try encodePartialReduction(
            command: command,
            uniforms: &uniforms,
            pipeline: pipeline,
            operation: operation,
            textures: textures,
            groupCount: groupCount
        )
        try encodeFinalReduction(
            command: command,
            groupCount: groupCount,
            result: result,
            resultOffset: resultOffset,
            uniforms: uniforms
        )
    }

    private func encodeStateKernel(
        _ pipeline: MTLComputePipelineState,
        command: MTLCommandBuffer,
        operation: String,
        status: StatusSlot,
        uniforms sourceUniforms: Fluid3DUniforms?,
        textures: [MTLTexture],
        extent: MTLSize,
        failureLatch: MTLBuffer? = nil
    ) throws {
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw PressureProjection3DError.encoderUnavailable(operation: operation)
        }
        encoder.label = "3D \(operation)"
        encoder.setComputePipelineState(pipeline)
        if let sourceUniforms {
            var uniforms = sourceUniforms
            encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
            encoder.setBuffer(status.buffer, offset: 0, index: 1)
        } else {
            encoder.setBuffer(status.buffer, offset: 0, index: 0)
        }
        if pipeline === initializeSolverStatePipeline || pipeline === finalizeProjectionDiagnosticsPipeline {
            encoder.setBuffer(failureLatch ?? standaloneLatch, offset: 0, index: 2)
        }
        for (index, texture) in textures.enumerated() {
            encoder.setTexture(texture, index: index)
        }
        encoder.dispatchThreads(
            extent,
            threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: pipeline)
        )
        encoder.endEncoding()
    }

    private enum PCGTraceStage: UInt32 {
        case recursiveResidual = 0
        case trueResidual = 1
    }

    private func encodePCGTrace(
        command: MTLCommandBuffer,
        status: StatusSlot,
        stage: PCGTraceStage,
        iteration: Int
    ) throws {
        guard let traceBuffer = status.pcgTraceBuffer else { return }
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw PressureProjection3DError.encoderUnavailable(operation: "capture PCG diagnostic trace")
        }
        var stageValue = stage.rawValue
        var iterationValue = UInt32(iteration)
        encoder.label = "3D capture PCG \(stage) trace"
        encoder.setComputePipelineState(capturePCGTracePipeline)
        encoder.setBuffer(status.buffer, offset: 0, index: 0)
        encoder.setBuffer(traceBuffer, offset: 0, index: 1)
        encoder.setBytes(&stageValue, length: MemoryLayout<UInt32>.stride, index: 2)
        encoder.setBytes(&iterationValue, length: MemoryLayout<UInt32>.stride, index: 3)
        encoder.dispatchThreads(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )
        encoder.endEncoding()
    }

    private func encodeWalls(
        command: MTLCommandBuffer,
        texture: MTLTexture,
        component: VolumeField3D.Component
    ) throws {
        let componentID = Self.componentID(component)
        try encode(
            enforceWallsPipeline,
            command: command,
            operation: "enforce \(component.rawValue) normal walls",
            output: texture,
            componentID: componentID,
            textures: [texture]
        )
    }

    func makeReductionResult(label: String) throws -> MTLBuffer {
        guard let result = metal.device.makeBuffer(
            length: MemoryLayout<SIMD4<Float>>.stride,
            options: .storageModeShared
        ) else {
            throw PressureProjection3DError.reductionResultAllocationFailed(label: label)
        }
        result.label = label
        return result
    }

    func makeStatusSlot(label: String, capturePCGTrace: Bool = false) throws -> StatusSlot {
        guard Fluid3DPCGState.abiIsValid else {
            throw PressureProjection3DError.reductionResultAllocationFailed(
                label: "invalid Swift/Metal PCG state ABI"
            )
        }
        guard let buffer = metal.device.makeBuffer(
            length: MemoryLayout<Fluid3DPCGState>.stride,
            options: .storageModeShared
        ) else {
            throw PressureProjection3DError.reductionResultAllocationFailed(label: label)
        }
        buffer.label = label
        buffer.contents().assumingMemoryBound(to: Fluid3DPCGState.self).pointee = Fluid3DPCGState()
        let traceBuffer: MTLBuffer?
        if capturePCGTrace {
            let traceByteCount = Self.maximumIterations * 2 * MemoryLayout<SIMD4<Float>>.stride
            guard let allocatedTrace = metal.device.makeBuffer(
                length: traceByteCount,
                options: .storageModeShared
            ) else {
                throw PressureProjection3DError.reductionResultAllocationFailed(
                    label: "PCG trace for \(label)"
                )
            }
            allocatedTrace.label = "\(label) PCG iteration trace"
            traceBuffer = allocatedTrace
        } else {
            traceBuffer = nil
        }
        return StatusSlot(
            buffer: buffer,
            deviceRegistryID: metal.device.registryID,
            pcgTraceBuffer: traceBuffer
        )
    }

    /// Encodes a complete bounded zero-mean diagonal-PCG projection without a
    /// CPU wait/readback. Each status slot must belong to this device and must
    /// not be reused until its command buffer completes.
    func encodeProjection(
        command: MTLCommandBuffer,
        u: MTLTexture,
        v: MTLTexture,
        w: MTLTexture,
        projectedU: MTLTexture,
        projectedV: MTLTexture,
        projectedW: MTLTexture,
        status: StatusSlot,
        iterationLimit: Int = maximumIterations,
        failureInjection: Fluid3DProjectionFailureInjection = .none,
        failureLatch: MTLBuffer? = nil
    ) throws {
        guard iterationLimit > 0 && iterationLimit <= Self.maximumIterations else {
            throw FluidSimulation3DError.invalidConfiguration(
                "PCG iteration limit must be in 1...\(Self.maximumIterations)"
            )
        }
        guard status.deviceRegistryID == metal.device.registryID else {
            throw PressureProjection3DError.invalidTexture(
                resource: "projection status slot", expected: "a status slot allocated by this Metal device"
            )
        }
        guard !configuration.isProduction || failureInjection == .none else {
            throw FluidSimulation3DError.invalidConfiguration(
                "PCG failure injection is available only for explicit fixture configurations"
            )
        }
        try validateFaceTextures(u: u, v: v, w: w)
        try validateFaceTexture(projectedU, component: .u, resource: "projected u")
        try validateFaceTexture(projectedV, component: .v, resource: "projected v")
        try validateFaceTexture(projectedW, component: .w, resource: "projected w")

        var stateUniforms = makeUniforms(output: pressure.ping)
        stateUniforms.grid.w = UInt32(iterationLimit)
        stateUniforms.output.w = failureInjection.rawValue
        stateUniforms.output.y = failureLatch == nil ? 0 : 1
        try encodeStateKernel(
            initializeSolverStatePipeline,
            command: command,
            operation: "initialize PCG status slot",
            status: status,
            uniforms: stateUniforms,
            textures: [],
            extent: MTLSize(width: 1, height: 1, depth: 1),
            failureLatch: failureLatch
        )

        try encodeDivergence(command: command, u: u, v: v, w: w, output: divergence.ping)
        try encodeRHS(command: command, divergence: divergence.ping, output: rhs.ping)
        try encodeReduction(
            command: command, input: rhs.ping, result: status.buffer,
            resultOffset: StateLane.rhsSummary.byteOffset
        )
        try encodeReduction(
            command: command, input: u, result: status.buffer,
            resultOffset: StateLane.uSummary.byteOffset
        )
        try encodeReduction(
            command: command, input: v, result: status.buffer,
            resultOffset: StateLane.vSummary.byteOffset
        )
        try encodeReduction(
            command: command, input: w, result: status.buffer,
            resultOffset: StateLane.wSummary.byteOffset
        )
        try encodeWallFluxReduction(
            command: command, u: u, v: v, w: w, result: status.buffer,
            resultOffset: StateLane.wallSummary.byteOffset
        )
        try encodeStateKernel(
            initializeProjectionStatusPipeline,
            command: command,
            operation: "validate compatible closed-box RHS",
            status: status,
            uniforms: makeUniforms(output: rhs.ping),
            textures: [],
            extent: MTLSize(width: 1, height: 1, depth: 1)
        )

        let cellExtent = MTLSize(width: configuration.nx, height: configuration.ny, depth: configuration.nz)
        let scalarUniforms = makeUniforms(output: pressure.ping)
        try encodeStateKernel(
            initializePCGFieldsPipeline,
            command: command,
            operation: "initialize zero-guess PCG fields",
            status: status,
            uniforms: scalarUniforms,
            textures: [rhs.ping, pressure.ping, recursiveResidual.ping, preconditioned.ping, pressure.pong],
            extent: cellExtent
        )
        try encodeReduction(
            command: command, input: preconditioned.ping, result: status.buffer,
            resultOffset: StateLane.preconditionerMean.byteOffset
        )
        try encodeValidateSummary(command: command, status: status, lane: .preconditionerMean, failure: .invalidPreconditionedResidual)
        try encodeStateKernel(
            projectPreconditionerPipeline,
            command: command,
            operation: "project initial preconditioned residual",
            status: status,
            uniforms: scalarUniforms,
            textures: [preconditioned.ping, preconditioned.pong, searchDirection.ping],
            extent: cellExtent
        )
        try encodeDotReduction(
            command: command,
            left: recursiveResidual.ping,
            right: preconditioned.pong,
            status: status,
            resultLane: .dotSummary
        )
        try encodeStateKernel(
            initializeRhoPipeline,
            command: command,
            operation: "initialize PCG rho",
            status: status,
            uniforms: nil,
            textures: [],
            extent: MTLSize(width: 1, height: 1, depth: 1)
        )

        for iteration in 1...iterationLimit {
            try encodeStateKernel(
                applySearchPipeline,
                command: command,
                operation: "apply A to PCG search direction",
                status: status,
                uniforms: scalarUniforms,
                textures: [searchDirection.ping, appliedOperator.ping],
                extent: cellExtent
            )
            try encodeDotReduction(
                command: command,
                left: searchDirection.ping,
                right: appliedOperator.ping,
                status: status,
                resultLane: .dotSummary
            )
            try encodeStateKernel(
                preparePCGUpdatePipeline, command: command, operation: "validate PCG denominator and alpha",
                status: status, uniforms: nil, textures: [], extent: MTLSize(width: 1, height: 1, depth: 1)
            )
            try encodeStateKernel(
                updatePCGPipeline,
                command: command,
                operation: "update PCG pressure and recurrence residual",
                status: status,
                uniforms: nil,
                textures: [pressure.ping, recursiveResidual.ping, searchDirection.ping, appliedOperator.ping, pressure.pong],
                extent: cellExtent
            )
            try encodePCGStateReduction(command: command, status: status)
            try encodeStateKernel(
                projectPressureResidualPipeline,
                command: command,
                operation: "project pressure and residual gauges",
                status: status,
                uniforms: scalarUniforms,
                textures: [pressure.ping, recursiveResidual.ping, pressure.pong],
                extent: cellExtent
            )
            try encodeReduction(
                command: command, input: recursiveResidual.ping, result: status.buffer,
                resultOffset: StateLane.recursiveResidualSummary.byteOffset
            )
            try encodeStateKernel(
                checkRecursiveResidualPipeline,
                command: command,
                operation: "check recursive PCG residual",
                status: status,
                uniforms: nil,
                textures: [],
                extent: MTLSize(width: 1, height: 1, depth: 1)
            )
            try encodePCGTrace(command: command, status: status, stage: .recursiveResidual, iteration: iteration)
            try encodeStateKernel(
                applyCandidatePipeline,
                command: command,
                operation: "apply A for true-residual candidate",
                status: status,
                uniforms: scalarUniforms,
                textures: [pressure.ping, appliedOperator.ping, pressure.pong],
                extent: cellExtent
            )
            try encodeStateKernel(
                computeCandidateResidualPipeline,
                command: command,
                operation: "recompute candidate true residual",
                status: status,
                uniforms: scalarUniforms,
                textures: [rhs.ping, appliedOperator.ping, trueResidual.ping],
                extent: cellExtent
            )
            try encodeReduction(
                command: command, input: trueResidual.ping, result: status.buffer,
                resultOffset: StateLane.trueResidualSummary.byteOffset
            )
            try encodeStateKernel(
                checkTrueResidualPipeline,
                command: command,
                operation: "accept or restart from true residual",
                status: status,
                uniforms: nil,
                textures: [],
                extent: MTLSize(width: 1, height: 1, depth: 1)
            )
            try encodePCGTrace(command: command, status: status, stage: .trueResidual, iteration: iteration)
            try encodeStateKernel(
                prepareRestartPipeline,
                command: command,
                operation: "replace recurrence residual after drift",
                status: status,
                uniforms: scalarUniforms,
                textures: [trueResidual.ping, recursiveResidual.ping],
                extent: cellExtent
            )
            try encodeStateKernel(
                preconditionVectorPipeline,
                command: command,
                operation: "diagonal PCG preconditioner",
                status: status,
                uniforms: scalarUniforms,
                textures: [recursiveResidual.ping, trueResidual.ping, preconditioned.ping],
                extent: cellExtent
            )
            try encodeReduction(
                command: command, input: preconditioned.ping, result: status.buffer,
                resultOffset: StateLane.preconditionerMean.byteOffset
            )
            try encodeValidateSummary(command: command, status: status, lane: .preconditionerMean, failure: .invalidPreconditionedResidual)
            try encodeStateKernel(
                projectPreconditionerPipeline,
                command: command,
                operation: "project preconditioned residual",
                status: status,
                uniforms: scalarUniforms,
                textures: [preconditioned.ping, preconditioned.pong, searchDirection.pong],
                extent: cellExtent
            )
            try encodeDotReduction(
                command: command,
                left: recursiveResidual.ping,
                right: preconditioned.pong,
                status: status,
                resultLane: .dotSummary
            )
            try encodeStateKernel(
                validateNextRhoPipeline,
                command: command,
                operation: "validate next PCG rho and beta",
                status: status,
                uniforms: nil,
                textures: [],
                extent: MTLSize(width: 1, height: 1, depth: 1)
            )
            try encodeStateKernel(
                updateDirectionPipeline,
                command: command,
                operation: "update PCG search direction",
                status: status,
                uniforms: nil,
                textures: [preconditioned.pong, searchDirection.ping],
                extent: cellExtent
            )
            try encodeStateKernel(
                finalizePCGDirectionPipeline,
                command: command,
                operation: "finalize PCG recurrence scalars",
                status: status,
                uniforms: nil,
                textures: [],
                extent: MTLSize(width: 1, height: 1, depth: 1)
            )
            try encodeReduction(
                command: command, input: searchDirection.ping, result: status.buffer,
                resultOffset: StateLane.pressureMean.byteOffset
            )
            try encodeValidateSummary(command: command, status: status, lane: .pressureMean, failure: .nonfiniteIterate)
            try encodeStateKernel(
                projectDirectionPipeline,
                command: command,
                operation: "project PCG search direction",
                status: status,
                uniforms: scalarUniforms,
                textures: [searchDirection.ping],
                extent: cellExtent
            )
        }

        try encodeReduction(
            command: command, input: pressure.ping, result: status.buffer,
            resultOffset: StateLane.pressureMean.byteOffset
        )
        try encodeValidateSummary(command: command, status: status, lane: .pressureMean, failure: .nonfiniteIterate)
        try encodeStateKernel(
            normalizePressureGaugePipeline,
            command: command,
            operation: "normalize final pressure gauge",
            status: status,
            uniforms: scalarUniforms,
            textures: [pressure.ping, pressure.pong],
            extent: cellExtent
        )
        try encode(
            applyACompensatedPipeline, command: command, operation: "paired pressure operator",
            output: appliedOperator.ping, textures: [pressure.ping, appliedOperator.ping, pressure.pong]
        )
        try encodeTrueResidual(
            command: command,
            divergence: divergence.ping,
            appliedOperator: appliedOperator.ping,
            output: trueResidual.ping
        )
        for (component, input, output) in [(UInt32(0), u, projectedU), (UInt32(1), v, projectedV), (UInt32(2), w, projectedW)] {
            try encode(
                subtractCompensatedGradientPipeline, command: command,
                operation: "paired pressure gradient", output: output, componentID: component,
                textures: [pressure.ping, input, output, pressure.pong]
            )
        }
        try encodeWalls(command: command, texture: projectedU, component: .u)
        try encodeWalls(command: command, texture: projectedV, component: .v)
        try encodeWalls(command: command, texture: projectedW, component: .w)
        try encodeDivergence(
            command: command,
            u: projectedU, v: projectedV, w: projectedW,
            output: divergence.pong
        )
        try encodeIdentityError(
            command: command,
            projectedDivergence: divergence.pong,
            trueResidual: trueResidual.ping,
            output: identityError.ping
        )
        try encodeReduction(
            command: command, input: trueResidual.ping, result: status.buffer,
            resultOffset: StateLane.trueResidualSummary.byteOffset
        )
        try encodeReduction(
            command: command, input: divergence.pong, result: status.buffer,
            resultOffset: StateLane.projectedDivergenceSummary.byteOffset
        )
        try encodeReduction(
            command: command, input: identityError.ping, result: status.buffer,
            resultOffset: StateLane.identityErrorSummary.byteOffset
        )
        try encodeWallFluxReduction(
            command: command, u: projectedU, v: projectedV, w: projectedW,
            result: status.buffer, resultOffset: StateLane.wallSummary.byteOffset
        )
        try encodeStateKernel(
            finalizeProjectionDiagnosticsPipeline,
            command: command,
            operation: "finalize true-residual and divergence acceptance",
            status: status,
            uniforms: scalarUniforms,
            textures: [],
            extent: MTLSize(width: 1, height: 1, depth: 1),
            failureLatch: failureLatch
        )
    }

    var diagnosticFields: [(String, VolumeField3D)] {
        [("q-high-low", pressure), ("divergence", divergence), ("rhs", rhs),
         ("Aq", appliedOperator), ("true-residual", trueResidual), ("identity", identityError),
         ("recursive-residual", recursiveResidual), ("preconditioned", preconditioned),
         ("search", searchDirection)]
    }

    func encodeClearScratch(command: MTLCommandBuffer, clearPipeline: MTLComputePipelineState) throws {
        for (_, field) in diagnosticFields {
            try field.encodeClear(command: command, pipeline: clearPipeline)
        }
        guard let blit = command.makeBlitCommandEncoder() else {
            throw PressureProjection3DError.encoderUnavailable(operation: "clear reduction workspace")
        }
        blit.fill(buffer: reductionPartials, range: 0..<reductionPartials.length, value: 0)
        blit.endEncoding()
    }

    var diagnosticReductionWorkspace: MTLBuffer { reductionPartials }

    private func encode(
        _ pipeline: MTLComputePipelineState,
        command: MTLCommandBuffer,
        operation: String,
        output: MTLTexture,
        componentID: UInt32 = 0,
        textures: [MTLTexture]
    ) throws {
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw PressureProjection3DError.encoderUnavailable(operation: operation)
        }
        var uniforms = makeUniforms(output: output, componentID: componentID)
        encoder.label = "3D \(operation)"
        encoder.setComputePipelineState(pipeline)
        encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
        for (index, texture) in textures.enumerated() {
            encoder.setTexture(texture, index: index)
        }
        encoder.dispatchThreads(
            MTLSize(width: output.width, height: output.height, depth: output.depth),
            threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: pipeline)
        )
        encoder.endEncoding()
    }

    private func encodePartialReduction(
        command: MTLCommandBuffer,
        uniforms: inout Fluid3DUniforms,
        pipeline: MTLComputePipelineState,
        operation: String,
        textures: [MTLTexture],
        groupCount: Int
    ) throws {
        guard groupCount <= reductionPartialCapacity else {
            throw PressureProjection3DError.reductionCapacityExceeded(
                required: groupCount,
                available: reductionPartialCapacity
            )
        }
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw PressureProjection3DError.encoderUnavailable(operation: "\(operation) partials")
        }
        encoder.label = "3D \(operation) partials"
        encoder.setComputePipelineState(pipeline)
        encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
        for (index, texture) in textures.enumerated() {
            encoder.setTexture(texture, index: index)
        }
        encoder.setBuffer(reductionPartials, offset: 0, index: 1)
        encoder.dispatchThreadgroups(
            MTLSize(width: groupCount, height: 1, depth: 1),
            threadsPerThreadgroup: reductionGroupSize
        )
        encoder.endEncoding()
    }

    private func encodeFinalReduction(
        command: MTLCommandBuffer,
        groupCount: Int,
        result: MTLBuffer,
        resultOffset: Int,
        uniforms sourceUniforms: Fluid3DUniforms
    ) throws {
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw PressureProjection3DError.encoderUnavailable(operation: "final scalar reduction")
        }
        var uniforms = sourceUniforms
        uniforms.grid.x = UInt32(groupCount)
        uniforms.output = SIMD4<UInt32>(1, 1, 1, 0)
        encoder.label = "3D reduction final scalar"
        encoder.setComputePipelineState(finalizeReductionPipeline)
        encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
        encoder.setBuffer(reductionPartials, offset: 0, index: 1)
        encoder.setBuffer(result, offset: resultOffset, index: 2)
        encoder.dispatchThreadgroups(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: finalReductionGroupSize
        )
        encoder.endEncoding()
    }

    private func groupCount(for elementCount: Int) throws -> Int {
        let rounded = elementCount.addingReportingOverflow(reductionGroupSize.width - 1)
        guard !rounded.overflow else {
            throw PressureProjection3DError.reductionCapacityExceeded(
                required: Int.max,
                available: reductionPartialCapacity
            )
        }
        return rounded.partialValue / reductionGroupSize.width
    }

    private func makeUniforms(output: MTLTexture, componentID: UInt32 = 0) -> Fluid3DUniforms {
        let grid = configuration
        return Fluid3DUniforms(
            grid: SIMD4<UInt32>(UInt32(grid.nx), UInt32(grid.ny), UInt32(grid.nz), 0),
            scale: SIMD4<Float>(grid.h, grid.dt, 1 / grid.h, grid.h * grid.h),
            output: SIMD4<UInt32>(
                UInt32(output.width), UInt32(output.height), UInt32(output.depth), componentID
            )
        )
    }

    private func validateCellTexture(_ texture: MTLTexture, resource: String) throws {
        guard texture.textureType == .type3D,
              texture.pixelFormat == .r32Float,
              texture.width == configuration.nx,
              texture.height == configuration.ny,
              texture.depth == configuration.nz else {
            throw PressureProjection3DError.invalidTexture(
                resource: resource,
                expected: "r32Float 3D cell extent \(configuration.nx)x\(configuration.ny)x\(configuration.nz)"
            )
        }
    }

    private func validateFaceTextures(u: MTLTexture, v: MTLTexture, w: MTLTexture) throws {
        try validateFaceTexture(u, component: .u, resource: "u")
        try validateFaceTexture(v, component: .v, resource: "v")
        try validateFaceTexture(w, component: .w, resource: "w")
    }

    private func validateFaceTexture(
        _ texture: MTLTexture,
        component: VolumeField3D.Component,
        resource: String
    ) throws {
        let dimensions = component.dimensions(for: configuration)
        guard texture.textureType == .type3D,
              texture.pixelFormat == .r32Float,
              texture.width == dimensions.width,
              texture.height == dimensions.height,
              texture.depth == dimensions.depth else {
            throw PressureProjection3DError.invalidTexture(
                resource: resource,
                expected: "r32Float 3D \(component.rawValue) extent \(dimensions.width)x\(dimensions.height)x\(dimensions.depth)"
            )
        }
    }

    private func validateReductionTexture(_ texture: MTLTexture, resource: String) throws {
        guard texture.textureType == .type3D, texture.pixelFormat == .r32Float,
              texture.width > 0, texture.height > 0, texture.depth > 0 else {
            throw PressureProjection3DError.invalidTexture(
                resource: resource,
                expected: "a nonempty r32Float 3D texture"
            )
        }
    }

    private func validateReductionResult(_ result: MTLBuffer, offset: Int) throws {
        let end = offset.addingReportingOverflow(MemoryLayout<SIMD4<Float>>.stride)
        guard offset >= 0, !end.overflow, result.length >= end.partialValue else {
            throw PressureProjection3DError.invalidTexture(
                resource: "reduction result buffer",
                expected: "at least \(offset + MemoryLayout<SIMD4<Float>>.stride) bytes"
            )
        }
    }

    private static func componentID(_ component: VolumeField3D.Component) -> UInt32 {
        switch component {
        case .u: 0
        case .v: 1
        case .w: 2
        case .cell: 3
        }
    }

    private static func makePipeline(_ function: String, metal: MetalDevice) throws -> MTLComputePipelineState {
        do {
            return try metal.createComputePipeline(computeFunctionName: function)
        } catch {
            throw PressureProjection3DError.pipelineCreationFailed(
                function: function,
                reason: String(describing: error)
            )
        }
    }

    private static func checkedProduct(_ first: Int, _ second: Int, _ third: Int) throws -> Int {
        let xy = first.multipliedReportingOverflow(by: second)
        let xyz = xy.partialValue.multipliedReportingOverflow(by: third)
        guard first > 0, second > 0, third > 0, !xy.overflow, !xyz.overflow else {
            throw PressureProjection3DError.reductionWorkspaceAllocationFailed(byteCount: Int.max)
        }
        return xyz.partialValue
    }

    private static func checkedWallFaceCount(_ configuration: FluidSimulation3DConfiguration) throws -> Int {
        let x = configuration.ny.multipliedReportingOverflow(by: configuration.nz)
        let y = configuration.nx.multipliedReportingOverflow(by: configuration.nz)
        let z = configuration.nx.multipliedReportingOverflow(by: configuration.ny)
        let sum = x.partialValue.addingReportingOverflow(y.partialValue)
        let total = sum.partialValue.addingReportingOverflow(z.partialValue)
        let doubled = total.partialValue.multipliedReportingOverflow(by: 2)
        guard !x.overflow, !y.overflow, !z.overflow,
              !sum.overflow, !total.overflow, !doubled.overflow else {
            throw PressureProjection3DError.reductionWorkspaceAllocationFailed(byteCount: Int.max)
        }
        return doubled.partialValue
    }
}

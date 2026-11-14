import Metal
import simd

enum TracerSystem3DError: Error, LocalizedError {
    case invalidPositionLayout(stride: Int, alignment: Int)
    case bufferAllocationFailed(resource: String, byteCount: Int)
    case pipelineCreationFailed(function: String, reason: String)
    case encoderUnavailable(operation: String)
    case invalidReadback(expectedByteCount: Int, actualByteCount: Int)
    case incompatibleReadbackStorageMode
    case incompatibleSimulationDevice
    case incompatibleSimulationDomain

    var errorDescription: String? {
        switch self {
        case .invalidPositionLayout(let stride, let alignment):
            "3D tracer SIMD4 layout must be 16-byte stride/alignment (got \(stride)/\(alignment))"
        case .bufferAllocationFailed(let resource, let byteCount):
            "Unable to allocate \(byteCount)-byte 3D tracer buffer for \(resource)"
        case .pipelineCreationFailed(let function, let reason):
            "Unable to create 3D tracer compute pipeline '\(function)': \(reason)"
        case .encoderUnavailable(let operation):
            "Unable to create Metal encoder for 3D tracer \(operation)"
        case .invalidReadback(let expectedByteCount, let actualByteCount):
            "Invalid 3D tracer readback: expected at least \(expectedByteCount) bytes, got \(actualByteCount)"
        case .incompatibleReadbackStorageMode:
            "3D tracer readback buffer must use shared storage"
        case .incompatibleSimulationDevice:
            "3D tracer and fluid simulation must use the same Metal device"
        case .incompatibleSimulationDomain:
            "3D tracers require a unit-cube simulation domain"
        }
    }
}

/// Owns deterministic passive 3D tracer positions, independently of fluid state.
/// Evolution scheduling is controlled by the logical simulation step owner.
@MainActor
final class TracerSystem3D {
    static let count = 512
    static let positionStride = MemoryLayout<SIMD4<Float>>.stride
    static let positionAlignment = MemoryLayout<SIMD4<Float>>.alignment
    static let positionByteCount = count * positionStride

    struct DiagnosticResourceInventory: Equatable {
        let markerCount: Int
        let positionBytes: Int
        let positionStride: Int
        let positionAlignment: Int
    }

    typealias BufferFactory = (Int, MTLResourceOptions) -> MTLBuffer?
    typealias PipelineFactory = (String) throws -> MTLComputePipelineState
    typealias ComputeEncoderFactory = (MTLCommandBuffer) -> MTLComputeCommandEncoder?

    private let positions: MTLBuffer
    private let resetPipeline: MTLComputePipelineState
    private let advancePipeline: MTLComputePipelineState
    private let metalDevice: MTLDevice
    private let deviceRegistryID: UInt64
    private let bufferFactory: BufferFactory
    private let computeEncoderFactory: ComputeEncoderFactory

    var diagnosticResourceInventory: DiagnosticResourceInventory {
        DiagnosticResourceInventory(
            markerCount: Self.count,
            positionBytes: positions.length,
            positionStride: Self.positionStride,
            positionAlignment: Self.positionAlignment
        )
    }

    init(
        metal: MetalDevice,
        bufferFactory: BufferFactory? = nil,
        pipelineFactory: PipelineFactory? = nil,
        computeEncoderFactory: ComputeEncoderFactory? = nil
    ) throws {
        guard Self.positionStride == 16, Self.positionAlignment == 16 else {
            throw TracerSystem3DError.invalidPositionLayout(
                stride: Self.positionStride,
                alignment: Self.positionAlignment
            )
        }

        let makeBuffer = bufferFactory ?? { length, options in
            metal.device.makeBuffer(length: length, options: options)
        }
        let makePipeline = pipelineFactory ?? { name in
            try metal.createComputePipeline(computeFunctionName: name)
        }
        metalDevice = metal.device
        deviceRegistryID = metal.device.registryID
        self.bufferFactory = makeBuffer
        self.computeEncoderFactory = computeEncoderFactory ?? { command in
            command.makeComputeCommandEncoder()
        }

        guard let positionBuffer = makeBuffer(Self.positionByteCount, .storageModePrivate) else {
            throw TracerSystem3DError.bufferAllocationFailed(
                resource: "positions",
                byteCount: Self.positionByteCount
            )
        }
        positionBuffer.label = "3D tracer positions"
        positions = positionBuffer

        do {
            resetPipeline = try makePipeline("fluid3DResetTracers")
        } catch {
            throw TracerSystem3DError.pipelineCreationFailed(
                function: "fluid3DResetTracers",
                reason: String(describing: error)
            )
        }
        do {
            advancePipeline = try makePipeline("fluid3DAdvanceTracers")
        } catch {
            throw TracerSystem3DError.pipelineCreationFailed(
                function: "fluid3DAdvanceTracers",
                reason: String(describing: error)
            )
        }
    }

    func encodeReset(command: MTLCommandBuffer) throws {
        guard let encoder = computeEncoderFactory(command) else {
            throw TracerSystem3DError.encoderUnavailable(operation: "reset compute")
        }
        encoder.label = "3D tracer deterministic reset"
        encoder.setComputePipelineState(resetPipeline)
        encoder.setBuffer(positions, offset: 0, index: 0)
        encoder.dispatchThreads(
            MTLSize(width: Self.count, height: 1, depth: 1),
            threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: resetPipeline)
        )
        encoder.endEncoding()
    }

    /// Advance markers once from the solver's newly projected velocity
    /// generation. Status and textures are consumed in command-buffer order;
    /// no CPU status readback is performed before encoding the dependent pass.
    func encodeAdvance(
        command: MTLCommandBuffer,
        simulation: FluidSimulation3D,
        status: PressureProjection3D.StatusSlot
    ) throws {
        guard simulation.metal.device.registryID == deviceRegistryID else {
            throw TracerSystem3DError.incompatibleSimulationDevice
        }
        let configuration = simulation.configuration
        guard configuration.h * Float(configuration.nx) == 1,
              configuration.h * Float(configuration.ny) == 1,
              configuration.h * Float(configuration.nz) == 1 else {
            throw TracerSystem3DError.incompatibleSimulationDomain
        }
        guard let encoder = computeEncoderFactory(command) else {
            throw TracerSystem3DError.encoderUnavailable(operation: "advance compute")
        }

        var uniforms = Fluid3DUniforms(
            grid: SIMD4(
                UInt32(configuration.nx), UInt32(configuration.ny),
                UInt32(configuration.nz), 0
            ),
            scale: SIMD4(configuration.h, configuration.dt, 0, 0),
            output: SIMD4(UInt32(Self.count), 0, 0, 0)
        )
        encoder.label = "3D passive tracer forward RK2 advance"
        encoder.setComputePipelineState(advancePipeline)
        encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
        encoder.setBuffer(positions, offset: 0, index: 1)
        do {
            try status.encodeReadOnlyBinding(to: encoder, index: 2, expectedDevice: metalDevice)
        } catch {
            encoder.endEncoding()
            throw error
        }
        encoder.setTexture(simulation.u.ping, index: 0)
        encoder.setTexture(simulation.v.ping, index: 1)
        encoder.setTexture(simulation.w.ping, index: 2)
        encoder.dispatchThreads(
            MTLSize(width: Self.count, height: 1, depth: 1),
            threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: advancePipeline)
        )
        encoder.endEncoding()
    }

    /// Encodes a private-to-shared snapshot. The caller must complete the command
    /// buffer before decoding the returned readback.
    func encodeReadback(command: MTLCommandBuffer) throws -> MTLBuffer {
        guard let readback = bufferFactory(Self.positionByteCount, .storageModeShared) else {
            throw TracerSystem3DError.bufferAllocationFailed(
                resource: "position readback",
                byteCount: Self.positionByteCount
            )
        }
        readback.label = "3D tracer position readback"
        guard let encoder = command.makeBlitCommandEncoder() else {
            throw TracerSystem3DError.encoderUnavailable(operation: "position readback blit")
        }
        encoder.label = "3D tracer position readback"
        encoder.copy(
            from: positions,
            sourceOffset: 0,
            to: readback,
            destinationOffset: 0,
            size: Self.positionByteCount
        )
        encoder.endEncoding()
        return readback
    }

    func decodeReadback(_ buffer: MTLBuffer) throws -> [SIMD4<Float>] {
        guard buffer.length >= Self.positionByteCount else {
            throw TracerSystem3DError.invalidReadback(
                expectedByteCount: Self.positionByteCount,
                actualByteCount: buffer.length
            )
        }
        guard buffer.storageMode == .shared else {
            throw TracerSystem3DError.incompatibleReadbackStorageMode
        }
        let source = buffer.contents().assumingMemoryBound(to: SIMD4<Float>.self)
        return (0..<Self.count).map { source[$0] }
    }
}

import Foundation
import Metal
import simd

/// Production 3D storage and transport, independent from the view-facing 2D
/// renderer. Callers serialize mutation and keep the command buffer ordering.
/// Projection is added separately; this transport object is not connected to UI.
@MainActor
final class FluidSimulation3D {
    enum Generation {
        case ping
        case pong
    }

    let metal: MetalDevice
    let configuration: FluidSimulation3DConfiguration
    let u: VolumeField3D
    let v: VolumeField3D
    let w: VolumeField3D
    let dye: VolumeField3D

    private let velocityPipeline: MTLComputePipelineState
    private let dyePipeline: MTLComputePipelineState
    private let wallsPipeline: MTLComputePipelineState
    private let clearPipeline: MTLComputePipelineState

    init(metal: MetalDevice, configuration: FluidSimulation3DConfiguration = .production) throws {
        self.metal = metal
        self.configuration = configuration
        u = try VolumeField3D(grid: configuration, component: .u, metal: metal)
        v = try VolumeField3D(grid: configuration, component: .v, metal: metal)
        w = try VolumeField3D(grid: configuration, component: .w, metal: metal)
        dye = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        velocityPipeline = try Self.makePipeline("fluid3DAdvectVelocity", metal: metal)
        dyePipeline = try Self.makePipeline("fluid3DAdvectDye", metal: metal)
        wallsPipeline = try Self.makePipeline("fluid3DEnforceWalls", metal: metal)
        clearPipeline = try Self.makePipeline("fluid3DClear", metal: metal)
    }

    /// Encodes the prerequisite transport stage in order: advect all velocity
    /// components from one old generation, impose exact walls, swap velocity,
    /// then advect dye with that completed transported velocity.
    func encodeAdvection(command: MTLCommandBuffer) throws {
        try encodeVelocityAdvection(command: command)
        try encodeWalls(command: command, generation: .pong)
        u.swap()
        v.swap()
        w.swap()
        try encodeDyeAdvection(command: command)
        dye.swap()
    }

    /// Enforces normal no-through-flow values on the active velocity generation.
    func encodeWalls(command: MTLCommandBuffer) throws {
        try encodeWalls(command: command, generation: .ping)
    }

    /// Clears both generations for deterministic construction/reset fixtures.
    func encodeClear(command: MTLCommandBuffer) throws {
        try u.encodeClear(command: command, pipeline: clearPipeline)
        try v.encodeClear(command: command, pipeline: clearPipeline)
        try w.encodeClear(command: command, pipeline: clearPipeline)
        try dye.encodeClear(command: command, pipeline: clearPipeline)
    }

    private func encodeVelocityAdvection(command: MTLCommandBuffer) throws {
        for (componentID, field) in [(UInt32(0), u), (UInt32(1), v), (UInt32(2), w)] {
            var uniforms = makeUniforms(
                operationID: 0,
                output: field,
                componentID: componentID
            )
            guard let encoder = command.makeComputeCommandEncoder() else {
                throw VolumeField3DError.encoderUnavailable(
                    operation: "3D \(field.component.rawValue) velocity advection"
                )
            }
            encoder.label = "3D \(field.component.rawValue) self-advection"
            encoder.setComputePipelineState(velocityPipeline)
            encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
            encoder.setTexture(u.ping, index: 0)
            encoder.setTexture(v.ping, index: 1)
            encoder.setTexture(w.ping, index: 2)
            encoder.setTexture(field.ping, index: 3)
            encoder.setTexture(field.pong, index: 4)
            encoder.dispatchThreads(
                MTLSize(width: field.width, height: field.height, depth: field.depth),
                threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: velocityPipeline)
            )
            encoder.endEncoding()
        }
    }

    private func encodeDyeAdvection(command: MTLCommandBuffer) throws {
        var uniforms = makeUniforms(operationID: 1, output: dye, componentID: 3)
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw VolumeField3DError.encoderUnavailable(operation: "3D dye advection")
        }
        encoder.label = "3D cell-centred dye advection"
        encoder.setComputePipelineState(dyePipeline)
        encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
        encoder.setTexture(u.ping, index: 0)
        encoder.setTexture(v.ping, index: 1)
        encoder.setTexture(w.ping, index: 2)
        encoder.setTexture(dye.ping, index: 3)
        encoder.setTexture(dye.pong, index: 4)
        encoder.dispatchThreads(
            MTLSize(width: dye.width, height: dye.height, depth: dye.depth),
            threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: dyePipeline)
        )
        encoder.endEncoding()
    }

    private func encodeWalls(command: MTLCommandBuffer, generation: Generation) throws {
        for (componentID, field) in [(UInt32(0), u), (UInt32(1), v), (UInt32(2), w)] {
            let output: MTLTexture = switch generation {
            case .ping: field.ping
            case .pong: field.pong
            }
            var uniforms = makeUniforms(
                operationID: 2,
                output: field,
                componentID: componentID
            )
            guard let encoder = command.makeComputeCommandEncoder() else {
                throw VolumeField3DError.encoderUnavailable(
                    operation: "3D \(field.component.rawValue) wall enforcement"
                )
            }
            encoder.label = "3D \(field.component.rawValue) exact wall enforcement"
            encoder.setComputePipelineState(wallsPipeline)
            encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
            encoder.setTexture(output, index: 0)
            encoder.dispatchThreads(
                MTLSize(width: field.width, height: field.height, depth: field.depth),
                threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: wallsPipeline)
            )
            encoder.endEncoding()
        }
    }

    private func makeUniforms(
        operationID: UInt32,
        output: VolumeField3D,
        componentID: UInt32
    ) -> Fluid3DUniforms {
        let grid = configuration
        return Fluid3DUniforms(
            grid: SIMD4<UInt32>(UInt32(grid.nx), UInt32(grid.ny), UInt32(grid.nz), operationID),
            scale: SIMD4<Float>(grid.h, grid.dt, 1 / grid.h, 1),
            output: SIMD4<UInt32>(UInt32(output.width), UInt32(output.height), UInt32(output.depth), componentID)
        )
    }

    private static func makePipeline(_ function: String, metal: MetalDevice) throws -> MTLComputePipelineState {
        do {
            return try metal.createComputePipeline(computeFunctionName: function)
        } catch {
            throw FluidSimulation3DError.pipelineCreationFailed(
                function: function,
                reason: String(describing: error)
            )
        }
    }
}

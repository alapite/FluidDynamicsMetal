import Foundation
import Metal
import simd

/// Production 3D storage and transport, independent from the view-facing 2D
/// renderer. Callers serialize mutation and keep the command buffer ordering.
/// The complete evolution path remains unconnected to UI until later plans.
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
    let projection: PressureProjection3D
    private let transportedU: VolumeField3D
    private let transportedV: VolumeField3D
    private let transportedW: VolumeField3D
    private let failureLatch: MTLBuffer

    private let velocityPipeline: MTLComputePipelineState
    private let dyePipeline: MTLComputePipelineState
    private let wallsPipeline: MTLComputePipelineState
    private let clearPipeline: MTLComputePipelineState
    private let guardedVelocityPipeline: MTLComputePipelineState
    private let guardedDyePipeline: MTLComputePipelineState
    private let restoreVelocityPipeline: MTLComputePipelineState

    init(metal: MetalDevice, configuration: FluidSimulation3DConfiguration = .production) throws {
        self.metal = metal
        self.configuration = configuration
        u = try VolumeField3D(grid: configuration, component: .u, metal: metal)
        v = try VolumeField3D(grid: configuration, component: .v, metal: metal)
        w = try VolumeField3D(grid: configuration, component: .w, metal: metal)
        dye = try VolumeField3D(grid: configuration, component: .cell, metal: metal)
        projection = try PressureProjection3D(metal: metal, configuration: configuration)
        transportedU = try VolumeField3D(grid: configuration, component: .u, metal: metal)
        transportedV = try VolumeField3D(grid: configuration, component: .v, metal: metal)
        transportedW = try VolumeField3D(grid: configuration, component: .w, metal: metal)
        guard let latch = metal.device.makeBuffer(length: 4, options: .storageModeShared) else {
            throw PressureProjection3DError.reductionResultAllocationFailed(label: "simulation failure latch")
        }
        latch.contents().storeBytes(of: UInt32(0), as: UInt32.self)
        failureLatch = latch
        velocityPipeline = try Self.makePipeline("fluid3DAdvectVelocity", metal: metal)
        dyePipeline = try Self.makePipeline("fluid3DAdvectDye", metal: metal)
        wallsPipeline = try Self.makePipeline("fluid3DEnforceWalls", metal: metal)
        clearPipeline = try Self.makePipeline("fluid3DClear", metal: metal)
        guardedVelocityPipeline = try Self.makePipeline("fluid3DAdvectVelocityGuarded", metal: metal)
        guardedDyePipeline = try Self.makePipeline("fluid3DAdvectDyeGuarded", metal: metal)
        restoreVelocityPipeline = try Self.makePipeline("fluid3DRestoreFailedVelocity", metal: metal)
    }

    var diagnosticFields: [(String, VolumeField3D)] {
        [("u", u), ("v", v), ("w", w), ("dye", dye),
         ("transport-u", transportedU), ("transport-v", transportedV), ("transport-w", transportedW)]
            + projection.diagnosticFields
    }

    /// Reset is ordered on the same queue as all advances. It clears a prior
    /// session failure, initializes every generation, and projects without a step.
    @discardableResult
    func encodeReset(
        command: MTLCommandBuffer,
        initialState: Fluid3DInitialState? = nil
    ) throws -> PressureProjection3D.StatusSlot {
        let seed = initialState ?? ExperimentRecipes3D.initialState(for: configuration)
        for (values, field) in [(seed.u, u), (seed.v, v), (seed.w, w), (seed.dye, dye)] {
            guard values.count == field.width * field.height * field.depth,
                  values.allSatisfy(\.isFinite) else {
                throw FluidSimulation3DError.invalidConfiguration("reset payload has invalid extent or nonfinite values")
            }
        }
        guard seed.dye.allSatisfy({ (0...1).contains($0) }) else {
            throw FluidSimulation3DError.invalidConfiguration("reset dye must be in 0...1")
        }
        let status = try projection.makeStatusSlot(label: "3D reset projection")
        try encodeClear(command: command)
        for field in [transportedU, transportedV, transportedW] {
            try field.encodeClear(command: command, pipeline: clearPipeline)
        }
        try projection.encodeClearScratch(command: command, clearPipeline: clearPipeline)
        guard let clear = command.makeBlitCommandEncoder() else {
            throw VolumeField3DError.encoderUnavailable(operation: "clear session latch")
        }
        clear.fill(buffer: failureLatch, range: 0..<failureLatch.length, value: 0)
        clear.endEncoding()
        for (values, field) in [(seed.u, u), (seed.v, v), (seed.w, w), (seed.dye, dye)] {
            try field.encodeUpload(values, to: field.pong, command: command)
            try field.encodeUpload(values, to: field.ping, command: command)
        }
        try encodeWalls(command: command, generation: .pong)
        try projection.encodeProjection(
            command: command, u: u.pong, v: v.pong, w: w.pong,
            projectedU: u.ping, projectedV: v.ping, projectedW: w.ping,
            status: status, failureLatch: failureLatch
        )
        for field in [u, v, w] { try copy(field.ping, to: field.pong, command: command) }
        return status
    }

    /// Every call returns its own retained status slot. The caller may queue
    /// three commands without diagnostic reuse and inspect only on completion.
    @discardableResult
    func encodeStep(
        command: MTLCommandBuffer,
        failureInjection: Fluid3DProjectionFailureInjection = .none
    ) throws -> PressureProjection3D.StatusSlot {
        guard !configuration.isProduction || failureInjection == .none else {
            throw FluidSimulation3DError.invalidConfiguration("failure injection is fixture-only")
        }
        let status = try projection.makeStatusSlot(label: "3D advance projection")
        for (component, input, transported) in [(UInt32(0), u, transportedU), (UInt32(1), v, transportedV), (UInt32(2), w, transportedW)] {
            try encodeGuarded(guardedVelocityPipeline, command: command, output: transported,
                              componentID: component, textures: [u.ping, v.ping, w.ping, input.ping, transported.ping])
            try enforceWalls(transported, command: command, componentID: component)
        }
        try projection.encodeProjection(
            command: command, u: transportedU.ping, v: transportedV.ping, w: transportedW.ping,
            projectedU: u.pong, projectedV: v.pong, projectedW: w.pong,
            status: status, failureInjection: failureInjection, failureLatch: failureLatch
        )
        for field in [u, v, w] {
            try encodeGuarded(restoreVelocityPipeline, command: command, output: field,
                              componentID: 0, textures: [field.ping, field.pong])
        }
        try encodeGuarded(guardedDyePipeline, command: command, output: dye, componentID: 3,
                          textures: [u.pong, v.pong, w.pong, dye.ping, dye.pong])
        u.swap(); v.swap(); w.swap(); dye.swap()
        return status
    }

    private func copy(_ source: MTLTexture, to destination: MTLTexture, command: MTLCommandBuffer) throws {
        guard let blit = command.makeBlitCommandEncoder() else {
            throw VolumeField3DError.encoderUnavailable(operation: "copy reset generation")
        }
        blit.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: source.width, height: source.height, depth: source.depth),
                  to: destination, destinationSlice: 0, destinationLevel: 0,
                  destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()
    }

    private func encodeGuarded(
        _ pipeline: MTLComputePipelineState, command: MTLCommandBuffer,
        output: VolumeField3D, componentID: UInt32, textures: [MTLTexture]
    ) throws {
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw VolumeField3DError.encoderUnavailable(operation: "guarded evolution")
        }
        var uniforms = makeUniforms(operationID: 0, output: output, componentID: componentID)
        encoder.setComputePipelineState(pipeline)
        encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
        encoder.setBuffer(failureLatch, offset: 0, index: 1)
        for (index, texture) in textures.enumerated() { encoder.setTexture(texture, index: index) }
        encoder.dispatchThreads(MTLSize(width: output.width, height: output.height, depth: output.depth),
                                threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: pipeline))
        encoder.endEncoding()
    }

    private func enforceWalls(_ field: VolumeField3D, command: MTLCommandBuffer, componentID: UInt32) throws {
        guard let encoder = command.makeComputeCommandEncoder() else {
            throw VolumeField3DError.encoderUnavailable(operation: "transport wall enforcement")
        }
        var uniforms = makeUniforms(operationID: 2, output: field, componentID: componentID)
        encoder.setComputePipelineState(wallsPipeline)
        encoder.setBytes(&uniforms, length: MemoryLayout<Fluid3DUniforms>.stride, index: 0)
        encoder.setTexture(field.ping, index: 0)
        encoder.dispatchThreads(MTLSize(width: field.width, height: field.height, depth: field.depth),
                                threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: wallsPipeline))
        encoder.endEncoding()
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

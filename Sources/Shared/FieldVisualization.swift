import Metal
import simd

@MainActor
final class FieldVisualization {
    let metal: MetalDevice
    let statistics: MTLBuffer
    private var partials: MTLBuffer
    private var partialCapacity = 1
    private let reduceFields: MTLComputePipelineState
    private let reduceStatistics: MTLComputePipelineState
    private let fieldPipeline: MTLRenderPipelineState
    private var outlineBuffers: [ExperimentID: (buffer: MTLBuffer, count: Int)] = [:]
    private let outlinePipeline: MTLRenderPipelineState
    private let arrowPipeline: MTLRenderPipelineState
    init(metal: MetalDevice = .sharedInstance) {
        self.metal = metal
        statistics = metal.device.makeBuffer(length: 16, options: .storageModePrivate)!
        partials = metal.device.makeBuffer(length: 32, options: .storageModePrivate)!
        func compute(_ name: String) -> MTLComputePipelineState {
            do { return try metal.createComputePipeline(computeFunctionName: name) }
            catch { fatalError("Metal compute pipeline initialization failed (function: \(name)): \(error)") }
        }
        reduceFields = compute("reduceFieldTiles"); reduceStatistics = compute("reduceFieldStatistics")
        do {
            fieldPipeline = try metal.createRenderPipeline(vertexFunctionName: "vertexShader", fragmentFunctionName: "displayField", pixelFormat: .bgra8Unorm)
            outlinePipeline = try metal.createRenderPipeline(vertexFunctionName: "startingOutlineVertex",
                fragmentFunctionName: "startingOutlineFragment", pixelFormat: .bgra8Unorm, blending: true)
            arrowPipeline = try metal.createRenderPipeline(vertexFunctionName: "arrowVertex", fragmentFunctionName: "arrowFragment", pixelFormat: .bgra8Unorm, blending: true)
        } catch { fatalError("Field visualization pipeline initialization failed: \(error)") }
    }
    func encodeStatistics(command: MTLCommandBuffer, simulation: FluidSimulation) {
        let groups = (simulation.width * simulation.height + 255) / 256
        if groups > partialCapacity {
            partialCapacity = groups
            partials = metal.device.makeBuffer(length: groups * 32, options: .storageModePrivate)!
        }
        let encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(reduceFields)
        encoder.setTexture(simulation.pressure.ping, index: 0)
        encoder.setTexture(simulation.velocity.ping, index: 1)
        encoder.setTexture(simulation.finalCurl.ping, index: 2)
        encoder.setBuffer(partials, offset: 0, index: 0)
        encoder.dispatchThreadgroups(MTLSize(width: groups, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
        encoder.setComputePipelineState(reduceStatistics)
        var counts = SIMD2<UInt32>(UInt32(groups), UInt32(simulation.width * simulation.height))
        encoder.setBuffer(statistics, offset: 0, index: 1)
        encoder.setBytes(&counts, length: 8, index: 2)
        encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
        encoder.endEncoding()
    }
    static func encoder(command: MTLCommandBuffer, destination: MTLTexture, viewport: MTLViewport, load: MTLLoadAction) -> MTLRenderCommandEncoder {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = destination
        pass.colorAttachments[0].loadAction = load
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
        encoder.setViewport(viewport)
        let x = max(0, Int(viewport.originX)), y = max(0, Int(viewport.originY))
        encoder.setScissorRect(MTLScissorRect(x: x, y: y, width: max(1, min(destination.width - x, Int(viewport.width))), height: max(1, min(destination.height - y, Int(viewport.height)))))
        return encoder
    }
    func encodeField(command: MTLCommandBuffer, simulation: FluidSimulation, destination: MTLTexture, viewport: MTLViewport, field: DisplayField) {
        encodeStatistics(command: command, simulation: simulation)
        let encoder = Self.encoder(command: command, destination: destination, viewport: viewport, load: .clear)
        encoder.setRenderPipelineState(fieldPipeline)
        encoder.setVertexBuffer(simulation.vertices, offset: 0, index: 0)
        encoder.setFragmentTexture(simulation.field(field), index: 0)
        encoder.setFragmentBuffer(statistics, offset: 0, index: 0)
        var choice = UInt32(field.rawValue)
        encoder.setFragmentBytes(&choice, length: 4, index: 1)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: simulation.indices, indexBufferOffset: 0)
        encoder.endEncoding()
    }
    func encodePresentation(command: MTLCommandBuffer, simulation: FluidSimulation, destination: MTLTexture,
                            viewport: MTLViewport, pointSize: SIMD2<Float>, mode: SimulationMode,
                            field: DisplayField, options: DisplayOptions, showsStartingOutline: Bool = false) {
        encodeField(command: command, simulation: simulation, destination: destination, viewport: viewport, field: field)
        if showsStartingOutline, let lesson = mode.experiment, lesson.supportsStartingOutline, field == .density {
            encodeStartingOutline(command: command, destination: destination, viewport: viewport,
                                  pointSize: pointSize, lesson: lesson)
        }
        if options.particles {
            simulation.particles.encodeDisplay(command: command, destination: destination, viewport: viewport,
                                               pointSize: pointSize, trails: options.trails, sparse: mode.experiment == .advection)
        }
        if options.arrows || field == .velocity {
            encodeArrows(command: command, simulation: simulation, destination: destination, viewport: viewport,
                         pointSize: pointSize, sparse: mode.experiment == .interactingVortices)
        }
    }
    private func encodeStartingOutline(command: MTLCommandBuffer, destination: MTLTexture,
                                       viewport: MTLViewport, pointSize: SIMD2<Float>, lesson: ExperimentID) {
        if outlineBuffers[lesson] == nil {
            let segments = ExperimentRecipes.startingOutline(lesson)
            let buffer = segments.withUnsafeBytes { bytes in
                bytes.baseAddress.flatMap { metal.device.makeBuffer(bytes: $0, length: bytes.count, options: .storageModeShared) }
            }
            guard let buffer else { return }
            buffer.label = "Step-zero dye contour: \(lesson.title)"
            outlineBuffers[lesson] = (buffer, segments.count)
        }
        guard let outline = outlineBuffers[lesson] else { return }
        let encoder = Self.encoder(command: command, destination: destination, viewport: viewport, load: .load)
        encoder.setRenderPipelineState(outlinePipeline)
        encoder.setVertexBuffer(outline.buffer, offset: 0, index: 0)
        var size = pointSize
        encoder.setVertexBytes(&size, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: outline.count)
        encoder.endEncoding()
    }

    func encodeArrows(command: MTLCommandBuffer, simulation: FluidSimulation, destination: MTLTexture, viewport: MTLViewport, pointSize: SIMD2<Float>, sparse: Bool = false) {
        let spacing: Float = sparse ? 64 : 32
        let maximum = sparse ? 8 : 32
        let columns = max(1, min(maximum, Int(pointSize.x / spacing)))
        let rows = max(1, min(maximum, Int(pointSize.y / spacing)))
        var parameters = SIMD4<Float>(pointSize.x, pointSize.y, Float(columns), Float(rows))
        let encoder = Self.encoder(command: command, destination: destination, viewport: viewport, load: .load)
        encoder.setRenderPipelineState(arrowPipeline)
        encoder.setVertexTexture(simulation.velocity.ping, index: 0)
        encoder.setVertexBytes(&parameters, length: 16, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: columns * rows)
        encoder.endEncoding()
    }
}

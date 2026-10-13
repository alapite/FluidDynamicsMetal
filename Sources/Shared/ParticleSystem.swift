import Metal
import simd

@MainActor
final class ParticleSystem {
    static let count = 256
    static let historyLength = 64
    let positions: MTLBuffer
    let history: MTLBuffer
    private(set) var head: UInt32 = 0
    private(set) var sampleCount: UInt32 = 1
    private let resetPipeline: MTLComputePipelineState
    private let advancePipeline: MTLComputePipelineState
    private let markerPipeline: MTLRenderPipelineState
    private let trailPipeline: MTLRenderPipelineState
    init(metal: MetalDevice) {
        positions = metal.device.makeBuffer(length: Self.count * 8, options: .storageModePrivate)!
        history = metal.device.makeBuffer(length: Self.count * Self.historyLength * 8, options: .storageModePrivate)!
        positions.label = "Normalized particle positions"; history.label = "64-sample particle history"
        func compute(_ name: String) -> MTLComputePipelineState {
            do { return try metal.createComputePipeline(computeFunctionName: name) }
            catch { fatalError("Metal compute pipeline initialization failed (function: \(name)): \(error)") }
        }
        resetPipeline = compute("resetParticles"); advancePipeline = compute("advanceParticles")
        do {
            markerPipeline = try metal.createRenderPipeline(vertexFunctionName: "particleVertex", fragmentFunctionName: "particleFragment", pixelFormat: .bgra8Unorm, blending: true)
            trailPipeline = try metal.createRenderPipeline(vertexFunctionName: "trailVertex", fragmentFunctionName: "trailFragment", pixelFormat: .bgra8Unorm, blending: true)
        } catch { fatalError("Particle overlay pipeline initialization failed: \(error)") }
    }
    func encodeReset(command: MTLCommandBuffer) {
        head = 0; sampleCount = 1
        let blit = command.makeBlitCommandEncoder()!
        blit.fill(buffer: history, range: 0..<history.length, value: 0); blit.endEncoding()
        let encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(resetPipeline)
        encoder.setBuffer(positions, offset: 0, index: 0); encoder.setBuffer(history, offset: 0, index: 1)
        encoder.dispatchThreads(MTLSize(width: Self.count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
        encoder.endEncoding()
    }
    func encodeAdvance(command: MTLCommandBuffer, velocity: MTLTexture) {
        head = (head + 1) % UInt32(Self.historyLength); sampleCount = min(UInt32(Self.historyLength), sampleCount + 1)
        var slot = head
        let encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(advancePipeline)
        encoder.setBuffer(positions, offset: 0, index: 0); encoder.setBuffer(history, offset: 0, index: 1)
        encoder.setBytes(&slot, length: 4, index: 2); encoder.setTexture(velocity, index: 0)
        encoder.dispatchThreads(MTLSize(width: Self.count, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
        encoder.endEncoding()
    }
    func encodeDisplay(command: MTLCommandBuffer, destination: MTLTexture, viewport: MTLViewport, pointSize: SIMD2<Float>, trails: Bool) {
        var parameters = SIMD4<Float>(pointSize.x, pointSize.y, Float(head), Float(sampleCount))
        let encoder = FieldVisualization.encoder(command: command, destination: destination, viewport: viewport, load: .load)
        encoder.setVertexBuffer(positions, offset: 0, index: 0)
        encoder.setVertexBuffer(history, offset: 0, index: 1)
        encoder.setVertexBytes(&parameters, length: 16, index: 2)
        if trails, sampleCount > 1 {
            encoder.setRenderPipelineState(trailPipeline)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: Self.count * Int(sampleCount - 1))
        }
        encoder.setRenderPipelineState(markerPipeline)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: Self.count)
        encoder.endEncoding()
    }
}

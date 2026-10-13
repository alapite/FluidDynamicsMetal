import Metal
import simd

/// Production GPU evolution shared by the view renderer and offscreen regression harness.
/// All resource mutation is serialized by the caller. No drawable or wall clock is used here.
@MainActor
final class FluidSimulation {
    static let vertexData: [VertexData] = [
        VertexData(position: [-1, -1], texCoord: [0, 1]), VertexData(position: [1, -1], texCoord: [1, 1]),
        VertexData(position: [-1, 1], texCoord: [0, 0]), VertexData(position: [1, 1], texCoord: [1, 0])]
    static let indexData: [UInt16] = [2, 1, 0, 1, 2, 3]
    let metal: MetalDevice
    private(set) var width: Int
    private(set) var height: Int
    private(set) var velocity: Slab
    private(set) var density: Slab
    private(set) var divergence: Slab
    private(set) var confinementCurl: Slab
    private(set) var finalCurl: Slab
    private(set) var pressure: Slab
    private(set) var particles: ParticleSystem
    private var stirring: [MTLTexture] = []
    let vertices: MTLBuffer
    let indices: MTLBuffer
    private var shaders: [String: RenderShader] = [:]
    var slabs: [Slab] { [velocity, density, divergence, confinementCurl, finalCurl, pressure] }
    var allTextures: [MTLTexture] { slabs.flatMap { [$0.ping!, $0.pong!] } }

    init(width: Int, height: Int, metal: MetalDevice = .sharedInstance) {
        self.metal = metal; self.width = width; self.height = height
        particles = ParticleSystem(metal: metal)
        func slab(_ name: String) -> Slab { Slab(width: width, height: height, format: .rg16Float, name: name, metalDevice: metal) }
        velocity = slab("Velocity"); density = slab("Dye"); divergence = slab("Divergence")
        confinementCurl = slab("Confinement curl"); finalCurl = slab("Final curl"); pressure = slab("Pressure")
        vertices = metal.buffer(array: Self.vertexData, storageMode: .storageModeShared)
        indices = metal.buffer(array: Self.indexData, storageMode: .storageModeShared)
        for name in ["advect", "advectVelocity", "applyForceVector", "applyForceScalar", "vorticity", "vorticityConfinement", "divergence", "jacobi", "gradient", "resampleField", "scriptedForce"] {
            shaders[name] = RenderShader(fragmentShader: name, vertexShader: "vertexShader", pixelFormat: .rg16Float, metalDevice: metal)
        }
    }
    func uniform(tuning: SimulationTuning) -> StaticData {
        let zeros: ContactTuple = (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
        return StaticData(positions: zeros, impulses: zeros, impulseScalar: .zero,
                          offsets: [1 / Float(width), 1 / Float(height)], screenSize: [Float(width), Float(height)],
                          inkRadius: tuning.radius, tuning: [tuning.dyeRetention, tuning.swirl, tuning.velocityRetention, 0])
    }
    func pass(_ name: String, command: MTLCommandBuffer, data: StaticData, sources: [MTLTexture], destination: MTLTexture) {
        var data = data
        shaders[name]!.calculateWithCommandBuffer(buffer: command, indices: indices, count: 6, texture: destination) { encoder in
            encoder.setVertexBuffer(self.vertices, offset: 0, index: 0)
            for (index, source) in sources.enumerated() { encoder.setFragmentTexture(source, index: index) }
            encoder.setFragmentBytes(&data, length: MemoryLayout<StaticData>.stride, index: 0)
        }
    }
    private func seedTexture(_ values: [SIMD2<Float>]) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = .shaderRead
        let texture = metal.device.makeTexture(descriptor: descriptor)!
        let halves = values.flatMap { [Float16($0.x), Float16($0.y)] }
        halves.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        return texture
    }
    func encodeReset(command: MTLCommandBuffer, mode: SimulationMode, adjustment: ExperimentAdjustment?) {
        Slab.clearInitialFields(allTextures, commandBuffer: command)
        particles.encodeReset(command: command)
        stirring.removeAll()
        if let id = mode.experiment, let adjustment {
            precondition(width == ExperimentRecipes.gridSize && height == ExperimentRecipes.gridSize)
            let seed = ExperimentRecipes.seed(id, adjustment: adjustment)
            let velocitySeed = seedTexture(seed.velocity), dyeSeed = seedTexture(seed.dye)
            let blit = command.makeBlitCommandEncoder()!
            for target in [velocity.ping!, velocity.pong!] { blit.copy(from: velocitySeed, to: target) }
            for target in [density.ping!, density.pong!] { blit.copy(from: dyeSeed, to: target) }
            blit.endEncoding()
            if id == .dyeStretching {
                // Positive Gaussian psi rotates clockwise in downward-positive texture coordinates.
                stirring = zip(ExperimentRecipes.stirringCenters, [Float(1), -1]).map {
                    seedTexture(ExperimentRecipes.vortexTemplate(centers: [$0.0], signs: [$0.1], sigma: ExperimentRecipes.stirringSigma))
                }
            }
        }
        encodeFinalCurl(command: command, data: uniform(tuning: .lesson))
    }
    func encodeFinalCurl(command: MTLCommandBuffer, data: StaticData) {
        pass("vorticity", command: command, data: data, sources: [velocity.ping], destination: finalCurl.pong); finalCurl.swap()
    }
    func encodeStep(command: MTLCommandBuffer, tuning: SimulationTuning, contacts: [FluidContact] = [], radius: Float? = nil,
                    mode: SimulationMode = .freePlay, adjustment: ExperimentAdjustment? = nil, step: Int) {
        var data = uniform(tuning: tuning)
        pass("advectVelocity", command: command, data: data, sources: [velocity.ping, velocity.ping], destination: velocity.pong); velocity.swap()
        pass("advect", command: command, data: data, sources: [velocity.ping, density.ping], destination: density.pong); density.swap()
        particles.encodeAdvance(command: command, velocity: velocity.ping)
        if mode == .freePlay {
            for batch in Renderer.contactBatches(contacts) {
                Renderer.writeContacts(batch, tuning: tuning, radius: radius ?? tuning.radius, to: &data)
                pass("applyForceVector", command: command, data: data, sources: [velocity.ping], destination: velocity.pong); velocity.swap()
                pass("applyForceScalar", command: command, data: data, sources: [density.ping], destination: density.pong); density.swap()
            }
        } else if mode == .experiment(.dyeStretching), step < 240 {
            data.impulseScalar.x = ExperimentRecipes.stirringAmplitude(step: step, adjustment: adjustment)
            pass("scriptedForce", command: command, data: data, sources: [velocity.ping, stirring[step / ExperimentRecipes.phaseLength]], destination: velocity.pong); velocity.swap()
        }
        pass("vorticity", command: command, data: data, sources: [velocity.ping], destination: confinementCurl.pong); confinementCurl.swap()
        pass("vorticityConfinement", command: command, data: data, sources: [velocity.ping, confinementCurl.ping], destination: velocity.pong); velocity.swap()
        pass("divergence", command: command, data: data, sources: [velocity.ping], destination: divergence.pong); divergence.swap()
        for _ in 0..<40 {
            pass("jacobi", command: command, data: data, sources: [pressure.ping, divergence.ping], destination: pressure.pong); pressure.swap()
        }
        pass("gradient", command: command, data: data, sources: [pressure.ping, velocity.ping], destination: velocity.pong); velocity.swap()
        encodeFinalCurl(command: command, data: data)
    }
    func field(_ field: DisplayField) -> MTLTexture {
        switch field {
        case .density: return density.ping
        case .pressure: return pressure.ping
        case .velocity: return velocity.ping
        case .vorticity: return finalCurl.ping
        }
    }
    func encodeResample(from old: FluidSimulation, command: MTLCommandBuffer) {
        particles = old.particles
        for (index, pair) in zip(old.slabs, slabs).enumerated() {
            var scale = index == 0 ? SIMD2<Float>(Float(width) / Float(old.width), Float(height) / Float(old.height)) : SIMD2<Float>(repeating: 1)
            for target in [pair.1.ping!, pair.1.pong!] {
                shaders["resampleField"]!.calculateWithCommandBuffer(buffer: command, indices: indices, count: 6, texture: target) { encoder in
                    encoder.setVertexBuffer(self.vertices, offset: 0, index: 0)
                    encoder.setFragmentTexture(pair.0.ping, index: 0)
                    encoder.setFragmentBytes(&scale, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
                }
            }
        }
        // The velocity scale changes with the grid; derive display curl again
        // even when a paused Free Play canvas is resized.
        encodeFinalCurl(command: command, data: uniform(tuning: .lesson))
    }
}

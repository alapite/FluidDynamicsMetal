import Foundation
import MetalKit

@main
@MainActor
struct RendererCorrectnessCheck {
    static func main() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(URL: URL(fileURLWithPath: CommandLine.arguments[1]))
        let check = GPUCheck(device: device, library: library)
        switch CommandLine.arguments[2] {
        case "initialization": try check.initialization()
        case "factory-errors": try check.factoryErrors()
        case "missing-vertex", "missing-fragment":
            let missingVertex = CommandLine.arguments[2] == "missing-vertex"
            _ = RenderShader(fragmentShader: missingVertex ? "advect" : "missingFragment",
                             vertexShader: missingVertex ? "missingVertex" : "vertexShader",
                             pixelFormat: .rg16Float,
                             metalDevice: MetalDevice(device: device, library: library))
            fatalError("An invalid shader unexpectedly initialized")
        default: fatalError("Unknown check")
        }
    }
}

@MainActor
final class GPUCheck {
    let device: MTLDevice
    let library: MTLLibrary
    let queue: MTLCommandQueue
    let vertices: MTLBuffer
    let indices: MTLBuffer
    let width = 16
    let height = 16

    init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        self.library = library
        queue = device.makeCommandQueue()!
        vertices = Renderer.vertexData.withUnsafeBytes {
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)!
        }
        indices = Renderer.indices.withUnsafeBytes {
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)!
        }
    }

    func texture() -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float,
                                                                 width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        let texture = device.makeTexture(descriptor: descriptor)!
        // Poison allocation contents so an omitted initialization cannot pass by luck.
        let pixels = [UInt16](repeating: Float16(7).bitPattern, count: width * height * 2)
        pixels.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                            withBytes: $0.baseAddress!, bytesPerRow: width * 4)
        }
        return texture
    }

    func finish(_ command: MTLCommandBuffer) {
        command.commit()
        command.waitUntilCompleted()
        precondition(command.status == .completed, "GPU failure: \(String(describing: command.error))")
    }

    func assertZero(_ texture: MTLTexture) {
        var pixels = [UInt16](repeating: 0xffff, count: width * height * 2)
        pixels.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        precondition(pixels.allSatisfy { Float16(bitPattern: $0).isFinite && Float16(bitPattern: $0) == 0 },
                     "Every field channel must remain finite and zero without input")
    }

    func apply(_ fragment: String, inputs: [MTLTexture], uniforms: MTLBuffer) throws -> MTLTexture {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: fragment)
        descriptor.colorAttachments[0].pixelFormat = .rg16Float
        let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let destination = texture()
        let command = queue.makeCommandBuffer()!
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = destination
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniforms, offset: 0, index: 0)
        for (index, input) in inputs.enumerated() { encoder.setFragmentTexture(input, index: index) }
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: Renderer.indices.count,
                                      indexType: .uint16, indexBuffer: indices, indexBufferOffset: 0)
        encoder.endEncoding()
        finish(command)
        return destination
    }

    func initialization() throws {
        var fields = (0..<5).map { _ in texture() }
        let command = queue.makeCommandBuffer()!
        Slab.clearInitialFields(fields, commandBuffer: command)
        finish(command)
        fields.forEach(assertZero)

        let zero = SIMD2<Float>.zero
        let contacts: ContactTuple = (zero, zero, zero, zero, zero, zero, zero, zero, zero, zero)
        var data = StaticData(positions: contacts, impulses: contacts, impulseScalar: zero,
                              offsets: SIMD2(1 / Float(width), 1 / Float(height)),
                              screenSize: SIMD2(Float(width), Float(height)), inkRadius: 150,
                              tuning: SIMD4(0.998, 0.4, 0, 0))
        let uniforms = device.makeBuffer(bytes: &data, length: MemoryLayout<StaticData>.stride,
                                         options: .storageModeShared)!
        // Run the production shaders in simulation order, including pressure warm-start.
        for _ in 0..<3 {
            fields[0] = try apply("advect", inputs: [fields[0], fields[0]], uniforms: uniforms)
            fields[1] = try apply("advect", inputs: [fields[0], fields[1]], uniforms: uniforms)
            fields[3] = try apply("vorticity", inputs: [fields[0]], uniforms: uniforms)
            fields[0] = try apply("vorticityConfinement", inputs: [fields[0], fields[3]], uniforms: uniforms)
            fields[2] = try apply("divergence", inputs: [fields[0]], uniforms: uniforms)
            for _ in 0..<40 {
                fields[4] = try apply("jacobi", inputs: [fields[4], fields[2]], uniforms: uniforms)
            }
            fields[0] = try apply("gradient", inputs: [fields[4], fields[0]], uniforms: uniforms)
            fields.forEach(assertZero)
        }
        print("PASS: initialization")
    }

    func factoryErrors() throws {
        let metal = MetalDevice(device: device, library: library)
        for missingVertex in [true, false] {
            let missing = missingVertex ? "missingVertex" : "missingFragment"
            do {
                _ = try metal.createRenderPipeline(vertexFunctionName: missingVertex ? missing : "vertexShader",
                                                    fragmentFunctionName: missingVertex ? "advect" : missing,
                                                    pixelFormat: .rg16Float)
                fatalError("The factory must reject missing functions")
            } catch MetalDeviceError.failedToCreateFunction(let name) {
                precondition(name == missing, "The error must identify the missing function")
            }
        }
        print("PASS: factory-errors")
    }
}

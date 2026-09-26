// Offscreen integration check of the Metal library shared by both app schemes.
// Invoked by test_phase02_metal.py after the macOS Debug build.
import Foundation
import Metal

let device = MTLCreateSystemDefaultDevice()!
let library = try device.makeLibrary(URL: URL(fileURLWithPath: CommandLine.arguments[1]))
let queue = device.makeCommandQueue()!
let width = 64
let height = 64

struct Vertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
}

let vertices = [
    Vertex(position: SIMD2(-1, -1), texCoord: SIMD2(0, 1)),
    Vertex(position: SIMD2(1, -1), texCoord: SIMD2(1, 1)),
    Vertex(position: SIMD2(-1, 1), texCoord: SIMD2(0, 0)),
    Vertex(position: SIMD2(1, 1), texCoord: SIMD2(1, 0)),
]
let indices: [UInt16] = [2, 1, 0, 1, 2, 3]
let vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])!
let indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count, options: [])!

func texture() -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: width, height: height, mipmapped: false)
    descriptor.usage = [.shaderRead, .renderTarget]
    descriptor.storageMode = .shared
    let texture = device.makeTexture(descriptor: descriptor)!
    let pixels = [UInt16](repeating: 0, count: width * height * 2)
    pixels.withUnsafeBytes {
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: $0.baseAddress!, bytesPerRow: width * 4)
    }
    return texture
}

func uniforms(position: SIMD2<Float>? = nil, impulse: SIMD2<Float> = .zero) -> MTLBuffer {
    // The fields and offsets here are the Swift StaticData / Metal BufferData wire contract.
    // Place the contact in the last slot so a five-slot shader or layout regression fails.
    let buffer = device.makeBuffer(length: 208, options: .storageModeShared)!
    let bytes = buffer.contents()
    bytes.initializeMemory(as: UInt8.self, repeating: 0, count: 208)
    if let position = position {
        bytes.advanced(by: 9 * 8).storeBytes(of: position, as: SIMD2<Float>.self)
        bytes.advanced(by: 80 + 9 * 8).storeBytes(of: impulse, as: SIMD2<Float>.self)
        bytes.advanced(by: 160).storeBytes(of: SIMD2<Float>(0.8, 0), as: SIMD2<Float>.self)
    }
    bytes.advanced(by: 168).storeBytes(of: SIMD2<Float>(1.0 / Float(width), 1.0 / Float(height)), as: SIMD2<Float>.self)
    bytes.advanced(by: 176).storeBytes(of: SIMD2<Float>(Float(width), Float(height)), as: SIMD2<Float>.self)
    bytes.advanced(by: 184).storeBytes(of: Float(150), as: Float.self)
    bytes.advanced(by: 192).storeBytes(of: SIMD4<Float>(0.998, 0.4, 0, 0), as: SIMD4<Float>.self)
    return buffer
}

@MainActor
func apply(_ fragment: String, source: MTLTexture, data: MTLBuffer) throws -> MTLTexture {
    let pipeline = MTLRenderPipelineDescriptor()
    pipeline.vertexFunction = library.makeFunction(name: "vertexShader")
    pipeline.fragmentFunction = library.makeFunction(name: fragment)
    pipeline.colorAttachments[0].pixelFormat = .rg16Float
    let state = try device.makeRenderPipelineState(descriptor: pipeline)
    let output = texture()
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    let command = queue.makeCommandBuffer()!
    let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
    encoder.setRenderPipelineState(state)
    encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    encoder.setFragmentTexture(source, index: 0)
    encoder.setFragmentBuffer(data, offset: 0, index: 0)
    encoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    guard command.status == .completed else {
        throw NSError(domain: "Phase02Metal", code: 1, userInfo: [NSLocalizedDescriptionKey: command.error?.localizedDescription ?? "GPU pass failed"])
    }
    return output
}

func center(_ texture: MTLTexture) -> SIMD2<Float> {
    var pixels = [UInt16](repeating: 0, count: width * height * 2)
    pixels.withUnsafeMutableBytes { bytes in
        texture.getBytes(bytes.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
    }
    let index = ((height / 2) * width + width / 2) * 2
    return SIMD2(Float(Float16(bitPattern: pixels[index])), Float(Float16(bitPattern: pixels[index + 1])))
}

func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
}

let empty = try apply("applyForceScalar", source: texture(), data: uniforms())
check(abs(center(empty).x) < 0.01, "Empty contacts must not inject density")

let lastSlot = uniforms(position: SIMD2<Float>(32.5, 32.5), impulse: SIMD2<Float>(3, -2))
let density = try apply("applyForceScalar", source: texture(), data: lastSlot)
check(center(density).x > 0.5, "The tenth contact must inject dye through the real shader")

let velocity = try apply("applyForceVector", source: texture(), data: lastSlot)
check(center(velocity).x > 1 && center(velocity).y < -0.5, "The tenth contact must apply independent vector force")

let released = try apply("applyForceScalar", source: density, data: uniforms())
check(abs(center(released).x - center(density).x) < 0.02, "Clearing contacts must not add stale dye")
let releasedVelocity = try apply("applyForceVector", source: velocity, data: uniforms())
check(abs(center(releasedVelocity).x - center(velocity).x) < 0.02 &&
      abs(center(releasedVelocity).y - center(velocity).y) < 0.02,
      "Clearing contacts must not add stale force")
print("PASS: Metal tenth-slot dye/force and empty-input release")

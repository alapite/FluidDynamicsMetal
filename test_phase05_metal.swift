import Foundation
import Metal

let device = MTLCreateSystemDefaultDevice()!
let library = try device.makeLibrary(URL: URL(fileURLWithPath: CommandLine.arguments[1]))
let queue = device.makeCommandQueue()!
struct Vertex { var position: SIMD2<Float>; var uv: SIMD2<Float> }
let vertices = [Vertex(position: SIMD2(-1, -1), uv: SIMD2(0, 1)), Vertex(position: SIMD2(1, -1), uv: SIMD2(1, 1)), Vertex(position: SIMD2(-1, 1), uv: SIMD2(0, 0)), Vertex(position: SIMD2(1, 1), uv: SIMD2(1, 0))]
let indices: [UInt16] = [2, 1, 0, 1, 2, 3]
let vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])!
let indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count, options: [])!

// Match Shared/Renderer.swift StaticData and Shared/Shaders.metal BufferData exactly.
struct Uniforms {
    var positions = [SIMD2<Float>](repeating: .zero, count: 10)
    var impulses = [SIMD2<Float>](repeating: .zero, count: 10)
    var scalar = SIMD2<Float>.zero
    var offsets = SIMD2<Float>(1 / 16, 1 / 16)
    var size = SIMD2<Float>(16, 16)
    var radius: Float = 150
    var tuning = SIMD4<Float>(0.998, 0.4, 0, 0)
}

func texture(_ fill: SIMD2<Float> = .zero, pattern: Bool = false) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: 16, height: 16, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = [.shaderRead, .renderTarget]
    let tex = device.makeTexture(descriptor: descriptor)!
    var bits = [UInt16](repeating: 0, count: 16 * 16 * 2)
    for y in 0..<16 { for x in 0..<16 {
        let value = pattern ? SIMD2(Float(x) / 16, Float(y) / 16) : fill
        let i = (y * 16 + x) * 2
        bits[i] = Float16(value.x).bitPattern
        bits[i + 1] = Float16(value.y).bitPattern
    } }
    bits.withUnsafeBytes { tex.replace(region: MTLRegionMake2D(0, 0, 16, 16), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 16 * 4) }
    return tex
}

func pixel(_ tex: MTLTexture, x: Int = 8, y: Int = 8) -> SIMD2<Float> {
    var bits = [UInt16](repeating: 0, count: 2)
    bits.withUnsafeMutableBytes { tex.getBytes($0.baseAddress!, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0) }
    return SIMD2(Float(Float16(bitPattern: bits[0])), Float(Float16(bitPattern: bits[1])))
}

@MainActor
func render(_ shader: String, _ first: MTLTexture, _ second: MTLTexture? = nil, _ uniforms: Uniforms) throws -> MTLTexture {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
    descriptor.fragmentFunction = library.makeFunction(name: shader)
    descriptor.colorAttachments[0].pixelFormat = .rg16Float
    let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    let output = texture()
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = .dontCare
    pass.colorAttachments[0].storeAction = .store
    let command = queue.makeCommandBuffer()!
    let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
    encoder.setRenderPipelineState(pipeline)
    encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    encoder.setFragmentTexture(first, index: 0)
    if let second = second { encoder.setFragmentTexture(second, index: 1) }
    // Swift arrays are not embedded inline in memory. Flatten into the production uniform layout.
    var data = [UInt8](repeating: 0, count: 208)
    data.withUnsafeMutableBytes { bytes in
        for index in 0..<10 {
            var position = uniforms.positions[index]
            var impulse = uniforms.impulses[index]
            withUnsafeBytes(of: &position) { bytes.baseAddress!.advanced(by: index * 8).copyMemory(from: $0.baseAddress!, byteCount: 8) }
            withUnsafeBytes(of: &impulse) { bytes.baseAddress!.advanced(by: 80 + index * 8).copyMemory(from: $0.baseAddress!, byteCount: 8) }
        }
        for (offset, value) in [(160, uniforms.scalar), (168, uniforms.offsets), (176, uniforms.size)] {
            var value = value
            withUnsafeBytes(of: &value) { bytes.baseAddress!.advanced(by: offset).copyMemory(from: $0.baseAddress!, byteCount: 8) }
        }
        var radius = uniforms.radius
        withUnsafeBytes(of: &radius) { bytes.baseAddress!.advanced(by: 184).copyMemory(from: $0.baseAddress!, byteCount: 4) }
        var tuning = uniforms.tuning
        withUnsafeBytes(of: &tuning) { bytes.baseAddress!.advanced(by: 192).copyMemory(from: $0.baseAddress!, byteCount: 16) }
    }
    let buffer = data.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: data.count, options: [])! }
    encoder.setFragmentBuffer(buffer, offset: 0, index: 0)
    encoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    guard command.status == .completed else { fatalError(command.error?.localizedDescription ?? "Metal command failed") }
    return output
}

func check(_ actual: Float, _ expected: Float, _ label: String, tolerance: Float = 0.02) {
    guard abs(actual - expected) < tolerance else { fatalError("\(label): expected \(expected), got \(actual)") }
}

let empty = texture()
var normal = Uniforms()
normal.positions[0] = SIMD2(8, 8)
normal.impulses[0] = SIMD2(1, 0)
normal.scalar = SIMD2(0.8, 0)
check(try pixel(render("applyForceVector", empty, nil, normal)).x, 1, "default force")
check(try pixel(render("applyForceScalar", empty, nil, normal)).x, 0.8, "default dye")
var dyeOnly = normal
dyeOnly.impulses[0] = .zero
check(try pixel(render("applyForceVector", empty, nil, dyeOnly)).x, 0, "zero force")
check(try pixel(render("applyForceScalar", empty, nil, dyeOnly)).x, 0.8, "dye with zero force")
var forceOnly = normal
forceOnly.scalar = .zero
check(try pixel(render("applyForceScalar", empty, nil, forceOnly)).x, 0, "zero dye")
check(try pixel(render("applyForceVector", empty, nil, forceOnly)).x, 1, "force with zero dye")

let stored = texture(SIMD2(1, 0.5))
var fade = Uniforms()
for name in ["velocity", "density"] {
    let baseline = try pixel(render("advect", empty, stored, fade))
    check(baseline.x, 0.998, "\(name) original retention", tolerance: 0.0007)
    fade.tuning.x = 0.9995
    let slower = try pixel(render("advect", empty, stored, fade))
    check(slower.x, 0.9995, "\(name) slowest fade", tolerance: 0.0007)
    fade.tuning.x = 0.9905
    let faster = try pixel(render("advect", empty, stored, fade))
    check(faster.x, 0.9905, "\(name) fastest fade", tolerance: 0.0007)
    guard slower.x > baseline.x, baseline.x > faster.x,
          slower.y > baseline.y, baseline.y > faster.y else {
        fatalError("\(name) fade did not increase to the right on both channels")
    }
    fade.tuning.x = 0.998
}

// Nonuniform vorticity with a nonzero gradient: curl acts on existing flow without contacts.
let curl = texture(pattern: true)
var zeroSwirl = Uniforms()
zeroSwirl.tuning.y = 0
let still = try pixel(render("vorticityConfinement", empty, curl, zeroSwirl))
check(still.x, 0, "zero swirl x")
check(still.y, 0, "zero swirl y")
let turning = try pixel(render("vorticityConfinement", empty, curl, Uniforms()))
guard abs(turning.x) > 0.01 || abs(turning.y) > 0.01 else { fatalError("default swirl failed to affect existing fluid") }
var strongSwirl = Uniforms()
strongSwirl.tuning.y = 2
let stronger = try pixel(render("vorticityConfinement", empty, curl, strongSwirl))
guard abs(stronger.x) + abs(stronger.y) > 4 * (abs(turning.x) + abs(turning.y)) else {
    fatalError("higher swirl did not increase curl on existing fluid")
}
print("GPU RG16F: default force=\(try pixel(render("applyForceVector", empty, nil, normal)).x), default dye=\(try pixel(render("applyForceScalar", empty, nil, normal)).x); zero-force velocity=\(try pixel(render("applyForceVector", empty, nil, dyeOnly)).x), zero-dye density=\(try pixel(render("applyForceScalar", empty, nil, forceOnly)).x)")
print("GPU RG16F: retention 0.9995 -> \(try pixel(render("advect", empty, stored, fadeWithRetention(0.9995))).x), retention 0.998 -> \(try pixel(render("advect", empty, stored, Uniforms())).x), retention 0.9905 -> \(try pixel(render("advect", empty, stored, fadeWithRetention(0.9905))).x); swirl 0 -> \(still), swirl 0.4 -> \(turning), swirl 2 -> \(stronger)")
print("PASS: force/dye independent; retention endpoints on both fields; swirl on stored vorticity")

func fadeWithRetention(_ retention: Float) -> Uniforms {
    var data = Uniforms()
    data.tuning.x = retention
    return data
}

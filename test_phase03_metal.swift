import Foundation
import Metal

let device = MTLCreateSystemDefaultDevice()!
let library = try device.makeLibrary(URL: URL(fileURLWithPath: CommandLine.arguments[1]))
let queue = device.makeCommandQueue()!
let sourceWidth = 64, sourceHeight = 32
let width = 32, height = 96
struct Vertex { var position: SIMD2<Float>; var texCoord: SIMD2<Float> }
let vertices = [Vertex(position: SIMD2(-1, -1), texCoord: SIMD2(0, 1)), Vertex(position: SIMD2(1, -1), texCoord: SIMD2(1, 1)), Vertex(position: SIMD2(-1, 1), texCoord: SIMD2(0, 0)), Vertex(position: SIMD2(1, 1), texCoord: SIMD2(1, 0))]
let indices: [UInt16] = [2, 1, 0, 1, 2, 3]
let vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])!
let indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count, options: [])!

func texture(_ w: Int, _ h: Int) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: w, height: h, mipmapped: false)
    descriptor.usage = [.shaderRead, .renderTarget]
    descriptor.storageMode = .shared
    return device.makeTexture(descriptor: descriptor)!
}

func pixel(_ tex: MTLTexture, _ x: Int, _ y: Int) -> SIMD2<Float> {
    var bits = [UInt16](repeating: 0, count: 2)
    bits.withUnsafeMutableBytes { tex.getBytes($0.baseAddress!, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0) }
    return SIMD2(Float(Float16(bitPattern: bits[0])), Float(Float16(bitPattern: bits[1])))
}

func check(_ actual: SIMD2<Float>, _ expected: SIMD2<Float>, _ label: String) {
    guard abs(actual.x - expected.x) < 0.06 && abs(actual.y - expected.y) < 0.06 else { fatalError("\(label): expected \(expected), got \(actual)") }
}

let source = texture(sourceWidth, sourceHeight)
var data = [UInt16](repeating: 0, count: sourceWidth * sourceHeight * 2)
func seed(_ x: Int, _ y: Int, _ value: SIMD2<Float>) {
    let offset = (y * sourceWidth + x) * 2
    data[offset] = Float16(value.x).bitPattern
    data[offset + 1] = Float16(value.y).bitPattern
}
let markers: [(Int, Int, Int, Int, SIMD2<Float>)] = [
    (0, 0, 0, 0, SIMD2(0.5, 0.25)), (63, 0, 31, 0, SIMD2(1, 0.5)),
    (0, 31, 0, 95, SIMD2(1.5, 0.75)), (63, 31, 31, 95, SIMD2(2, 1)),
    (32, 16, 16, 49, SIMD2(3, 1.5))
]
for (sx, sy, _, _, value) in markers {
    for y in max(0, sy - 1)...min(sourceHeight - 1, sy + 1) {
        for x in max(0, sx - 1)...min(sourceWidth - 1, sx + 1) { seed(x, y, value) }
    }
}
data.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, sourceWidth, sourceHeight), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: sourceWidth * 4) }

let pipeline = MTLRenderPipelineDescriptor()
pipeline.vertexFunction = library.makeFunction(name: "vertexShader")
pipeline.fragmentFunction = library.makeFunction(name: "resampleField")
pipeline.colorAttachments[0].pixelFormat = .rg16Float
let state = try device.makeRenderPipelineState(descriptor: pipeline)

func resample(_ scale: SIMD2<Float>) -> MTLTexture {
    let output = texture(width, height)
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = .dontCare
    pass.colorAttachments[0].storeAction = .store
    let command = queue.makeCommandBuffer()!
    let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
    encoder.setRenderPipelineState(state)
    encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    encoder.setFragmentTexture(source, index: 0)
    var factors = scale
    encoder.setFragmentBytes(&factors, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
    encoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    guard command.status == .completed else { fatalError(command.error?.localizedDescription ?? "Metal resize failed") }
    return output
}

for name in ["density", "pressure"] {
    let result = resample(SIMD2(1, 1))
    for (_, _, x, y, value) in markers { check(pixel(result, x, y), value, "\(name) \(x),\(y)") }
}
let velocity = resample(SIMD2(0.5, 3))
for (_, _, x, y, value) in markers { check(pixel(velocity, x, y), value * SIMD2(0.5, 3), "velocity \(x),\(y)") }
print("PASS: RG16F full-canvas resample 64x32 -> 32x96 density/pressure/velocity edges and center; tolerance 0.06")

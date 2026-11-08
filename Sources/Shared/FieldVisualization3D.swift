import Metal
import simd

enum FieldVisualization3DError: Error, LocalizedError {
    case invalidDestinationFormat(MTLPixelFormat)
    case invalidViewport
    case renderEncoderUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidDestinationFormat(let format):
            "3D slice destination must use bgra8Unorm, got \(format.rawValue)"
        case .invalidViewport:
            "3D slice viewport must have finite positive dimensions"
        case .renderEncoderUnavailable:
            "Unable to create the 3D slice render encoder"
        }
    }
}

/// Read-only face-on view of the fixed world-Z midpoint of a 3D dye field.
/// Palette values are sRGB-encoded channel values written directly to a
/// non-sRGB UNORM target; neither the shader nor render target applies gamma.
@MainActor
final class FieldVisualization3D {
    struct PaletteStop: Equatable {
        let concentration: Float
        let color: SIMD3<Float>
    }

    private struct Vertex: BitwiseCopyable {
        var position: SIMD2<Float>
        var worldXY: SIMD2<Float>
    }

    private struct PaletteUniforms: BitwiseCopyable {
        var black: SIMD4<Float>
        var amber: SIMD4<Float>
        var cream: SIMD4<Float>
        var stops: SIMD4<Float>
    }

    static let paletteStops: [PaletteStop] = [
        PaletteStop(concentration: 0, color: SIMD3<Float>(0, 0, 0)),
        PaletteStop(concentration: 0.5, color: SIMD3<Float>(Float(237) / 255, Float(139) / 255, Float(35) / 255)),
        PaletteStop(concentration: 1, color: SIMD3<Float>(1, Float(241) / 255, Float(214) / 255)),
    ]

    static let destinationPixelFormat: MTLPixelFormat = .bgra8Unorm

    private static let vertices: [Vertex] = [
        Vertex(position: [-1, -1], worldXY: [0, 0]),
        Vertex(position: [1, -1], worldXY: [1, 0]),
        Vertex(position: [-1, 1], worldXY: [0, 1]),
        Vertex(position: [1, 1], worldXY: [1, 1]),
    ]
    private static let indexData: [UInt16] = [2, 1, 0, 1, 2, 3]

    private let vertices: MTLBuffer
    private let indices: MTLBuffer
    private let pipeline: MTLRenderPipelineState

    init(metal: MetalDevice) throws {
        vertices = metal.buffer(array: Self.vertices, storageMode: .storageModeShared)
        indices = metal.buffer(array: Self.indexData, storageMode: .storageModeShared)
        pipeline = try metal.createRenderPipeline(
            vertexFunctionName: "fluid3DVertex",
            fragmentFunctionName: "fluid3DFixedSlice",
            pixelFormat: Self.destinationPixelFormat
        )
    }

    /// Encodes a black-cleared, read-only fixed slice. The supplied viewport is
    /// the canvas bounds; the rendered region is always the largest centered
    /// square inside it. Rendering never advances or writes simulation fields.
    func encodeSlice(
        command: MTLCommandBuffer,
        simulation: FluidSimulation3D,
        destination: MTLTexture,
        viewport: MTLViewport
    ) throws {
        guard destination.pixelFormat == Self.destinationPixelFormat else {
            throw FieldVisualization3DError.invalidDestinationFormat(destination.pixelFormat)
        }
        guard viewport.originX.isFinite, viewport.originY.isFinite,
              viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 0, viewport.height > 0 else {
            throw FieldVisualization3DError.invalidViewport
        }

        let left = max(0, viewport.originX)
        let top = max(0, viewport.originY)
        let right = min(Double(destination.width), viewport.originX + viewport.width)
        let bottom = min(Double(destination.height), viewport.originY + viewport.height)
        let availableWidth = right - left
        let availableHeight = bottom - top
        let side = min(availableWidth, availableHeight)
        guard side > 0 else { throw FieldVisualization3DError.invalidViewport }

        let square = MTLViewport(
            originX: left + (availableWidth - side) * 0.5,
            originY: top + (availableHeight - side) * 0.5,
            width: side,
            height: side,
            znear: viewport.znear,
            zfar: viewport.zfar
        )
        let scissorX = max(0, Int(floor(square.originX)))
        let scissorY = max(0, Int(floor(square.originY)))
        let scissorRight = min(destination.width, Int(ceil(square.originX + side)))
        let scissorBottom = min(destination.height, Int(ceil(square.originY + side)))

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = destination
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            throw FieldVisualization3DError.renderEncoderUnavailable
        }
        encoder.label = "3D fixed central XY dye slice"
        encoder.setViewport(square)
        encoder.setScissorRect(MTLScissorRect(
            x: scissorX,
            y: scissorY,
            width: max(1, scissorRight - scissorX),
            height: max(1, scissorBottom - scissorY)
        ))
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setFragmentTexture(simulation.dye.ping, index: 0)
        var palette = PaletteUniforms(
            black: SIMD4<Float>(Self.paletteStops[0].color, 1),
            amber: SIMD4<Float>(Self.paletteStops[1].color, 1),
            cream: SIMD4<Float>(Self.paletteStops[2].color, 1),
            stops: SIMD4<Float>(
                Self.paletteStops[0].concentration,
                Self.paletteStops[1].concentration,
                Self.paletteStops[2].concentration,
                0
            )
        )
        encoder.setFragmentBytes(&palette, length: MemoryLayout<PaletteUniforms>.stride, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: Self.indexData.count,
            indexType: .uint16,
            indexBuffer: indices,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
    }

    /// Encoded-channel color for the fixed transfer function, also suitable
    /// for a native legend. A nonfinite input remains nonfinite, not black.
    static func encodedColor(for concentration: Float) -> SIMD4<Float> {
        guard concentration.isFinite else { return SIMD4<Float>(repeating: .nan) }
        let value = min(1, max(0, concentration))
        let lowStop = paletteStops[0]
        let middleStop = paletteStops[1]
        let highStop = paletteStops[2]
        let rgb: SIMD3<Float>
        if value <= middleStop.concentration {
            let amount = (value - lowStop.concentration)
                / (middleStop.concentration - lowStop.concentration)
            rgb = lowStop.color + (middleStop.color - lowStop.color) * amount
        } else {
            let amount = (value - middleStop.concentration)
                / (highStop.concentration - middleStop.concentration)
            rgb = middleStop.color + (highStop.color - middleStop.color) * amount
        }
        return SIMD4<Float>(rgb, 1)
    }
}

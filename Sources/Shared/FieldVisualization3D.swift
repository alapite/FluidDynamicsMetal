import Metal
import simd

enum FieldVisualization3DError: Error, LocalizedError {
    case invalidDestinationFormat(MTLPixelFormat)
    case invalidSpatialDestination
    case invalidViewport
    case renderEncoderUnavailable
    case spatialPipelineFunctionUnavailable(String)
    case spatialDepthStateUnavailable
    case depthAttachmentAllocationFailed(width: Int, height: Int)
    case invalidPointScale

    var errorDescription: String? {
        switch self {
        case .invalidDestinationFormat(let format):
            "3D slice destination must use bgra8Unorm, got \(format.rawValue)"
        case .invalidSpatialDestination:
            "3D inspection destination must be a single-sample bgra8Unorm render target"
        case .invalidViewport:
            "3D slice viewport must be finite, positive, and contained by the destination"
        case .renderEncoderUnavailable:
            "Unable to create the 3D slice render encoder"
        case .spatialPipelineFunctionUnavailable(let name):
            "Unable to create the 3D spatial render pipeline: missing function \(name)"
        case .spatialDepthStateUnavailable:
            "Unable to create the 3D spatial depth state"
        case .depthAttachmentAllocationFailed(let width, let height):
            "Unable to allocate a \(width)x\(height) 3D inspection depth attachment"
        case .invalidPointScale:
            "3D inspection point scale must be finite and positive"
        }
    }
}

private final class DepthAttachmentRetention: @unchecked Sendable {
    let texture: MTLTexture

    init(_ texture: MTLTexture) {
        self.texture = texture
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

    private struct SpatialInspectionUniforms: BitwiseCopyable {
        var worldToClip: simd_float4x4
        var slice: SIMD4<Float>
        var viewport: SIMD4<Float>
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
    private let spatialPipeline: MTLRenderPipelineState
    private let spatialDepthState: MTLDepthStencilState
    private let device: MTLDevice
    private var depthAttachment: MTLTexture?

    init(metal: MetalDevice) throws {
        device = metal.device
        vertices = metal.buffer(array: Self.vertices, storageMode: .storageModeShared)
        indices = metal.buffer(array: Self.indexData, storageMode: .storageModeShared)
        pipeline = try metal.createRenderPipeline(
            vertexFunctionName: "fluid3DVertex",
            fragmentFunctionName: "fluid3DFixedSlice",
            pixelFormat: Self.destinationPixelFormat
        )
        spatialPipeline = try Self.makeSpatialPipeline(device: metal.device, library: metal.defaultLibrary)
        guard let depthState = Self.makeSpatialDepthState(device: metal.device) else {
            throw FieldVisualization3DError.spatialDepthStateUnavailable
        }
        spatialDepthState = depthState
        Self.assertSpatialUniformLayout()
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

    /// Encodes an opaque, two-sided fixed-world plane using continuous-depth
    /// cell-centred sampling and the same transfer function as the legacy path.
    /// It reads only the production dye texture and owns only presentation depth.
    func encodeInspection(
        command: MTLCommandBuffer,
        simulation: FluidSimulation3D,
        destination: MTLTexture,
        viewport: MTLViewport,
        inspection: InspectionState3D,
        pointScale: Float,
        increaseContrast: Bool
    ) throws {
        guard destination.pixelFormat == Self.destinationPixelFormat else {
            throw FieldVisualization3DError.invalidDestinationFormat(destination.pixelFormat)
        }
        guard destination.width > 0, destination.height > 0,
              destination.sampleCount == 1,
              destination.usage.contains(.renderTarget) else {
            throw FieldVisualization3DError.invalidSpatialDestination
        }
        guard viewport.originX.isFinite, viewport.originY.isFinite,
              viewport.width.isFinite, viewport.height.isFinite,
              viewport.znear.isFinite, viewport.zfar.isFinite,
              viewport.originX >= 0, viewport.originY >= 0,
              viewport.width >= 0, viewport.height >= 0,
              viewport.znear >= 0, viewport.zfar <= 1, viewport.zfar > viewport.znear else {
            throw FieldVisualization3DError.invalidViewport
        }
        // A temporarily zero-sized drawable is normal during layout/resize.
        // Defer only this presentation; never make it a solver/resource error.
        guard viewport.width > 0, viewport.height > 0 else { return }
        let right = viewport.originX + viewport.width
        let bottom = viewport.originY + viewport.height
        guard right.isFinite, bottom.isFinite,
              right <= Double(destination.width), bottom <= Double(destination.height) else {
            throw FieldVisualization3DError.invalidViewport
        }
        guard pointScale.isFinite, pointScale > 0 else {
            throw FieldVisualization3DError.invalidPointScale
        }
        guard inspection.depth.isFinite, (0...1).contains(inspection.depth),
              InspectionPlane3D.allCases.contains(inspection.plane) else {
            throw FieldVisualization3DError.invalidViewport
        }

        let frame: CameraFrame3D
        do {
            frame = try Camera3D.frame(
                state: inspection.camera,
                viewportSize: CGSize(width: viewport.width, height: viewport.height)
            )
        } catch {
            throw FieldVisualization3DError.invalidViewport
        }
        let depth = try depthAttachment(width: destination.width, height: destination.height)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = destination
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .store
        pass.depthAttachment.clearDepth = 1

        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            throw FieldVisualization3DError.renderEncoderUnavailable
        }
        encoder.label = "3D spatial inspection sheet"
        encoder.setViewport(viewport)
        encoder.setScissorRect(MTLScissorRect(
            x: Int(floor(viewport.originX)),
            y: Int(floor(viewport.originY)),
            width: max(1, Int(ceil(right)) - Int(floor(viewport.originX))),
            height: max(1, Int(ceil(bottom)) - Int(floor(viewport.originY)))
        ))
        encoder.setCullMode(.none)
        encoder.setRenderPipelineState(spatialPipeline)
        encoder.setDepthStencilState(spatialDepthState)
        var uniforms = SpatialInspectionUniforms(
            worldToClip: frame.worldToClip,
            slice: SIMD4<Float>(
                Float(inspection.depth),
                Float(inspection.plane.rawValue),
                0,
                0
            ),
            viewport: SIMD4<Float>(Float(viewport.width), Float(viewport.height), pointScale, 0)
        )
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<SpatialInspectionUniforms>.stride, index: 0)
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
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        // Keep the selected generation alive when a resize replaces the cached
        // attachment while this command remains in flight.
        let depthRetention = DepthAttachmentRetention(depth)
        command.addCompletedHandler { _ in
            withExtendedLifetime(depthRetention) {}
        }
        _ = increaseContrast
    }

    private func depthAttachment(width: Int, height: Int) throws -> MTLTexture {
        if let depthAttachment,
           depthAttachment.width == width,
           depthAttachment.height == height,
           depthAttachment.pixelFormat == .depth32Float,
           depthAttachment.sampleCount == 1 {
            return depthAttachment
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget]
        guard let replacement = device.makeTexture(descriptor: descriptor) else {
            throw FieldVisualization3DError.depthAttachmentAllocationFailed(width: width, height: height)
        }
        replacement.label = "3D inspection depth \(width)x\(height)"
        depthAttachment = replacement
        return replacement
    }

    private static func makeSpatialPipeline(
        device: MTLDevice,
        library: MTLLibrary
    ) throws -> MTLRenderPipelineState {
        guard let vertex = library.makeFunction(name: "fluid3DSpatialVertex") else {
            throw FieldVisualization3DError.spatialPipelineFunctionUnavailable("fluid3DSpatialVertex")
        }
        guard let fragment = library.makeFunction(name: "fluid3DSpatialSlice") else {
            throw FieldVisualization3DError.spatialPipelineFunctionUnavailable("fluid3DSpatialSlice")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "3D spatial inspection sheet"
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = Self.destinationPixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.rasterSampleCount = 1
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeSpatialDepthState(device: MTLDevice) -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: descriptor)
    }

    private static func assertSpatialUniformLayout() {
        precondition(MemoryLayout<SpatialInspectionUniforms>.offset(of: \.worldToClip) == 0)
        precondition(MemoryLayout<SpatialInspectionUniforms>.offset(of: \.slice) == 64)
        precondition(MemoryLayout<SpatialInspectionUniforms>.offset(of: \.viewport) == 80)
        precondition(MemoryLayout<SpatialInspectionUniforms>.size == 96)
        precondition(MemoryLayout<SpatialInspectionUniforms>.stride == 96)
        precondition(MemoryLayout<SpatialInspectionUniforms>.alignment == 16)
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

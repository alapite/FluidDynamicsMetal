import AVFoundation
import CoreGraphics
import ImageIO
import Metal
import UniformTypeIdentifiers

@main @MainActor
struct PresentationAssetCapture {
    nonisolated private static let clipSize = 512
    private static let framesPerSecond: Int32 = 30
    private static let frames = 120

    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            throw CaptureError.failed("Usage: capture-presentation-assets <default.metallib> <repository directory>")
        }
        let library = URL(fileURLWithPath: CommandLine.arguments[1])
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let shared = root.appending(path: "Sources/Shared", directoryHint: .isDirectory)
        let sharedCatalog = shared.appending(path: "Assets.xcassets", directoryHint: .isDirectory)
        let macCatalog = root.appending(path: "Sources/macOS/Assets.xcassets", directoryHint: .isDirectory)
        let evidence = root.appending(path: ".build/presentation-asset-evidence", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)

        guard let device = MTLCreateSystemDefaultDevice() else { throw CaptureError.failed("No Metal device") }
        let metal = MetalDevice(device: device, library: try device.makeLibrary(URL: library))
        let still = try await captureFreePlay(
            metal: metal, videoURL: shared.appending(path: "FreePlayPreview.mp4"),
            workingDirectory: evidence
        )
        try await verifyPreview(at: shared.appending(path: "FreePlayPreview.mp4"), evidence: evidence)
        try save(still.image(), to: evidence.appending(path: "free-play-final-frame.png"))
        try saveAsset(still.image(), name: "FreePlayPreviewStill", in: sharedCatalog)
        try saveThumbnail(still, subject: .blueDye, name: "ExperimentFreePlay", in: sharedCatalog)

        let lessons: [(ExperimentID, ExperimentAdjustment, Int, Subject, String)] = [
            (.advection, .speed(.normal), 240, .blueDye, "ExperimentAdvection"),
            (.interactingVortices, .rotation(.opposite), 120, .pairedVortices, "ExperimentVortices"),
            (.dyeStretching, .strength(.normal), 240, .blueDye, "ExperimentStretching")
        ]
        for (lesson, adjustment, steps, subject, name) in lessons {
            let capture = try captureLesson(lesson, adjustment: adjustment, steps: steps, metal: metal)
            try save(capture.image(), to: evidence.appending(path: "\(name)-step-\(steps).png"))
            try saveThumbnail(capture, subject: subject, name: name, in: sharedCatalog)
        }

        let spatial = try captureSpatialLesson(metal: metal)
        try save(spatial.image(), to: evidence.appending(path: "ExperimentDye3D-step-0.png"))
        try saveThumbnail(spatial, subject: .inspection, name: "ExperimentDye3D", in: macCatalog)
    }

    private static func captureFreePlay(metal: MetalDevice, videoURL: URL, workingDirectory: URL) async throws -> Raster {
        let simulation = FluidSimulation(width: clipSize, height: clipSize, metal: metal)
        let visualization = FieldVisualization(metal: metal)
        let target = try renderTarget(device: metal.device)
        let temporaryVideo = workingDirectory.appending(path: "\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: temporaryVideo) }

        let writer = try AVAssetWriter(outputURL: temporaryVideo, fileType: .mp4)
        let h264: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: clipSize,
            AVVideoHeightKey: clipSize,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_800_000],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: h264)
        let pixels = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: clipSize,
            kCVPixelBufferHeightKey as String: clipSize
        ])
        guard writer.canAdd(video) else { throw CaptureError.failed("H.264 video input unavailable") }
        writer.add(video)
        guard writer.startWriting() else { throw writer.error ?? CaptureError.failed("Could not start video writer") }
        writer.startSession(atSourceTime: .zero)

        try submit(metal) { simulation.encodeReset(command: $0, mode: .freePlay, adjustment: nil) }
        let tuning = SimulationTuning()
        for frame in 0..<frames {
            try submit(metal) { command in
                for step in (frame * 2)..<(frame * 2 + 2) {
                    simulation.encodeStep(command: command, tuning: tuning, contacts: scriptedContacts(step: step), step: step)
                }
                visualization.encodePresentation(
                    command: command, simulation: simulation, destination: target, viewport: viewport,
                    pointSize: SIMD2(repeating: Float(clipSize) / 2), mode: .freePlay,
                    field: .density, options: DisplayOptions()
                )
            }
            for _ in 0..<500 where !video.isReadyForMoreMediaData {
                guard writer.status == .writing else { break }
                try await Task.sleep(for: .milliseconds(2))
            }
            guard video.isReadyForMoreMediaData, let pool = pixels.pixelBufferPool else {
                throw writer.error ?? CaptureError.failed("Video writer did not accept frame \(frame)")
            }
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else {
                throw CaptureError.failed("Could not allocate video frame \(frame)")
            }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
                target.getBytes(baseAddress, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                from: MTLRegionMake2D(0, 0, clipSize, clipSize), mipmapLevel: 0)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard pixels.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: framesPerSecond)) else {
                throw writer.error ?? CaptureError.failed("Could not append video frame \(frame)")
            }
        }
        writer.endSession(atSourceTime: CMTime(value: Int64(frames), timescale: framesPerSecond))
        video.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CaptureError.failed("Video export did not finish") }
        try Data(contentsOf: temporaryVideo).write(to: videoURL, options: .atomic)
        return Raster(texture: target)
    }

    private static func verifyPreview(at url: URL, evidence: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard tracks.count == 1, audioTracks.isEmpty,
              duration.seconds == Double(frames) / Double(framesPerSecond) else {
            throw CaptureError.failed("Preview must contain one four-second video track and no audio")
        }
        let size = try await tracks[0].load(.naturalSize)
        let frameRate = try await tracks[0].load(.nominalFrameRate)
        guard size == CGSize(width: clipSize, height: clipSize), frameRate == Float(framesPerSecond) else {
            throw CaptureError.failed("Preview has an unexpected size or frame rate")
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for sample in [10, 20, 30, 60, 90, frames - 1] {
            let frame = try await generator.image(at: CMTime(value: Int64(sample), timescale: framesPerSecond))
            try save(frame.image, to: evidence.appending(path: "preview-decoded-frame-\(sample).png"))
        }
        print("Verified \(duration.seconds) s, \(Int(frameRate)) fps, \(Int(size.width)) × \(Int(size.height)), no audio")
    }

    private static func scriptedContacts(step: Int) -> [FluidContact] {
        // Two opposing arcs travel around the same center and leave the
        // injected tangential motion to curl the dye after the drags end.
        [(delay: 0, phase: Float(-2.9)), (delay: 16, phase: Float.pi - 2.9)].compactMap { stroke in
            let sample = step - stroke.delay
            let length = 34
            guard (0..<length).contains(sample) else { return nil }

            func point(at index: Int) -> SIMD2<Float> {
                let progress = Float(index) / Float(length - 1)
                let angle = stroke.phase + 2.45 * progress
                let radius = (0.22 - 0.045 * progress) * Float(clipSize)
                return SIMD2(repeating: Float(clipSize) / 2) + SIMD2(cos(angle), sin(angle)) * radius
            }
            let position = point(at: sample)
            return FluidContact(position: position, impulse: position - point(at: max(0, sample - 1)))
        }
    }

    private static func captureLesson(
        _ lesson: ExperimentID, adjustment: ExperimentAdjustment, steps: Int, metal: MetalDevice
    ) throws -> Raster {
        let simulation = FluidSimulation(width: ExperimentRecipes.gridSize, height: ExperimentRecipes.gridSize, metal: metal)
        let visualization = FieldVisualization(metal: metal)
        let target = try renderTarget(device: metal.device)
        let mode = SimulationMode.experiment(lesson)
        try submit(metal) { simulation.encodeReset(command: $0, mode: mode, adjustment: adjustment) }
        for step in 0..<steps {
            try submit(metal) { simulation.encodeStep(command: $0, tuning: .lesson, mode: mode, adjustment: adjustment, step: step) }
        }
        try submit(metal) { command in
            visualization.encodePresentation(
                command: command, simulation: simulation, destination: target, viewport: viewport,
                pointSize: SIMD2(repeating: Float(clipSize) / 2), mode: mode,
                field: lesson.defaultField, options: DisplayOptions()
            )
        }
        return Raster(texture: target)
    }

    private static func captureSpatialLesson(metal: MetalDevice) throws -> Raster {
        let simulation = try FluidSimulation3D(metal: metal)
        let visualization = try FieldVisualization3D(metal: metal)
        let tracers = try TracerSystem3D(metal: metal)
        let target = try renderTarget(device: metal.device)
        try submit(metal) { command in
            try simulation.encodeReset(command: command)
            try tracers.encodeReset(command: command)
        }
        try submit(metal) { command in
            try visualization.encodeInspection(
                command: command, simulation: simulation, tracers: tracers, destination: target,
                viewport: viewport, inspection: InspectionState3D(), pointScale: 2, increaseContrast: false
            )
        }
        return Raster(texture: target)
    }

    private static var viewport: MTLViewport {
        MTLViewport(originX: 0, originY: 0, width: Double(clipSize), height: Double(clipSize), znear: 0, zfar: 1)
    }

    private static func renderTarget(device: MTLDevice) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: clipSize, height: clipSize, mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw CaptureError.failed("Could not allocate capture target")
        }
        return texture
    }

    private static func submit(_ metal: MetalDevice, _ encode: (MTLCommandBuffer) throws -> Void) throws {
        let command = metal.newCommandBuffer()
        try encode(command)
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else {
            throw command.error ?? CaptureError.failed("GPU capture command did not finish")
        }
    }

    private enum Subject {
        case blueDye, pairedVortices, inspection

        func includes(blue: Int, green: Int, red: Int) -> Bool {
            switch self {
            case .blueDye:
                blue >= 55 && blue - red >= 24
            case .pairedVortices:
                max(red, green, blue) - min(red, green, blue) >= 36
            case .inspection:
                max(red, green, blue) >= 44
            }
        }
    }

    private static func saveThumbnail(_ raster: Raster, subject: Subject, name: String, in catalog: URL) throws {
        let source = try raster.image()
        let crop = try raster.crop(around: subject)
        print("\(name): \(crop)")
        guard let clipped = source.cropping(to: crop),
              let context = CGContext(data: nil, width: 96, height: 96, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: Raster.colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw CaptureError.failed("Could not allocate thumbnail \(name)")
        }
        context.interpolationQuality = .high
        context.draw(clipped, in: CGRect(x: 0, y: 0, width: 96, height: 96))
        guard let thumbnail = context.makeImage() else { throw CaptureError.failed("Could not render thumbnail \(name)") }
        try saveAsset(thumbnail, name: name, in: catalog)
    }

    private static func saveAsset(_ image: CGImage, name: String, in catalog: URL) throws {
        let imageSet = catalog.appending(path: "\(name).imageset", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: imageSet, withIntermediateDirectories: true)
        try save(image, to: imageSet.appending(path: "\(name).png"))
        let metadata = [
            "images": [["filename": "\(name).png", "idiom": "universal"]],
            "info": ["author": "xcode", "version": 1]
        ] as [String: Any]
        var contents = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        contents.append(0x0A)
        try contents.write(to: imageSet.appending(path: "Contents.json"), options: .atomic)
    }

    private static func save(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CaptureError.failed("Could not open \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.failed("Could not write \(url.lastPathComponent)")
        }
    }

    private struct Raster {
        static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let size: Int
        let bgra: [UInt8]

        init(texture: MTLTexture) {
            size = texture.width
            var data = [UInt8](repeating: 0, count: size * size * 4)
            texture.getBytes(&data, bytesPerRow: size * 4, from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
            bgra = data
        }

        func image() throws -> CGImage {
            let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little)
            guard let pixels = CGDataProvider(data: Data(bgra) as CFData),
                  let image = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                                      bytesPerRow: size * 4, space: Self.colorSpace, bitmapInfo: info,
                                      provider: pixels, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
                throw CaptureError.failed("Could not form an image from the capture")
            }
            return image
        }

        func crop(around subject: Subject) throws -> CGRect {
            var left = size, right = -1, top = size, bottom = -1
            for y in 0..<size {
                for x in 0..<size {
                    let index = (y * size + x) * 4
                    guard subject.includes(blue: Int(bgra[index]), green: Int(bgra[index + 1]), red: Int(bgra[index + 2])) else { continue }
                    left = min(left, x)
                    right = max(right, x)
                    top = min(top, y)
                    bottom = max(bottom, y)
                }
            }
            guard right >= left, bottom >= top else { throw CaptureError.failed("Thumbnail subject was not visible") }
            let extent = max(right - left + 1, bottom - top + 1)
            let side = min(size, Int(ceil(Double(extent) * 1.3)))
            let x = min(size - side, max(0, (left + right + 1 - side) / 2))
            let y = min(size - side, max(0, (top + bottom + 1 - side) / 2))
            return CGRect(x: x, y: y, width: side, height: side)
        }
    }

    private enum CaptureError: LocalizedError {
        case failed(String)

        var errorDescription: String? {
            switch self {
            case let .failed(message): message
            }
        }
    }
}

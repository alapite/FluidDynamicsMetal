import Foundation
import Metal

enum VolumeField3DError: Error, LocalizedError {
    case textureAllocationFailed(resource: String)
    case stagingBufferAllocationFailed(resource: String, byteCount: Int)
    case stagingSizeOverflow(resource: String)
    case invalidUploadCount(resource: String, expected: Int, actual: Int)
    case nonFiniteUpload(resource: String, index: Int)
    case textureNotOwned(resource: String)
    case encoderUnavailable(operation: String)
    case invalidReadback(resource: String, expectedByteCount: Int, actualByteCount: Int)

    var errorDescription: String? {
        switch self {
        case .textureAllocationFailed(let resource):
            "Unable to allocate private 3D texture for \(resource)"
        case .stagingBufferAllocationFailed(let resource, let byteCount):
            "Unable to allocate \(byteCount)-byte staging buffer for \(resource)"
        case .stagingSizeOverflow(let resource):
            "3D staging layout overflow for \(resource)"
        case .invalidUploadCount(let resource, let expected, let actual):
            "Invalid \(resource) upload length: expected \(expected) Float32 values, got \(actual)"
        case .nonFiniteUpload(let resource, let index):
            "Nonfinite input at \(resource) x-fastest index \(index)"
        case .textureNotOwned(let resource):
            "Texture passed to \(resource) is not one of its ping/pong generations"
        case .encoderUnavailable(let operation):
            "Unable to create Metal encoder for \(operation)"
        case .invalidReadback(let resource, let expectedByteCount, let actualByteCount):
            "Invalid \(resource) readback buffer: expected at least \(expectedByteCount) bytes, got \(actualByteCount)"
        }
    }
}

/// A checked Float32 3D ping/pong pair with explicit cell/MAC face extents.
/// Private textures are transferred through aligned shared staging buffers;
/// callers must complete the command buffer before decoding a readback buffer.
@MainActor
final class VolumeField3D {
    enum Component: String, CaseIterable, Hashable {
        case cell
        case u
        case v
        case w

        func dimensions(for grid: FluidSimulation3DConfiguration) -> (width: Int, height: Int, depth: Int) {
            switch self {
            case .cell: (grid.nx, grid.ny, grid.nz)
            case .u: (grid.nx + 1, grid.ny, grid.nz)
            case .v: (grid.nx, grid.ny + 1, grid.nz)
            case .w: (grid.nx, grid.ny, grid.nz + 1)
            }
        }
    }

    struct StagingLayout: Equatable {
        let bytesPerRow: Int
        let bytesPerImage: Int
        let totalBytes: Int
    }

    typealias TextureFactory = (MTLTextureDescriptor) -> MTLTexture?

    let grid: FluidSimulation3DConfiguration
    let component: Component
    let width: Int
    let height: Int
    let depth: Int
    let stagingLayout: StagingLayout
    private let metal: MetalDevice
    private(set) var ping: MTLTexture
    private(set) var pong: MTLTexture

    init(
        grid: FluidSimulation3DConfiguration,
        component: Component,
        metal: MetalDevice,
        textureFactory: TextureFactory? = nil
    ) throws {
        self.grid = grid
        self.component = component
        self.metal = metal
        let dimensions = component.dimensions(for: grid)
        width = dimensions.width
        height = dimensions.height
        depth = dimensions.depth
        stagingLayout = try Self.makeStagingLayout(
            width: dimensions.width,
            height: dimensions.height,
            depth: dimensions.depth,
            device: metal.device,
            resource: "\(component.rawValue) 3D field"
        )

        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .r32Float
        descriptor.width = dimensions.width
        descriptor.height = dimensions.height
        descriptor.depth = dimensions.depth
        descriptor.mipmapLevelCount = 1
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite]
        let createTexture = textureFactory ?? { metal.device.makeTexture(descriptor: $0) }

        let pingName = "3D \(component.rawValue) ping"
        guard let first = createTexture(descriptor) else {
            throw VolumeField3DError.textureAllocationFailed(resource: pingName)
        }
        first.label = pingName
        guard let second = createTexture(descriptor) else {
            throw VolumeField3DError.textureAllocationFailed(resource: "3D \(component.rawValue) pong")
        }
        second.label = "3D \(component.rawValue) pong"
        ping = first
        pong = second
    }

    func swap() {
        Swift.swap(&ping, &pong)
    }

    func makeBlitEncoder(command: MTLCommandBuffer, operation: String) throws -> MTLBlitCommandEncoder {
        guard let encoder = command.makeBlitCommandEncoder() else {
            throw VolumeField3DError.encoderUnavailable(operation: "\(component.rawValue) \(operation)")
        }
        encoder.label = "3D \(component.rawValue) \(operation)"
        return encoder
    }

    func encodeUpload(_ values: [Float], to texture: MTLTexture, command: MTLCommandBuffer) throws {
        try validateOwned(texture)
        let expectedCount = try Self.checkedProduct(width, height, depth, resource: "\(component.rawValue) upload")
        guard values.count == expectedCount else {
            throw VolumeField3DError.invalidUploadCount(
                resource: component.rawValue,
                expected: expectedCount,
                actual: values.count
            )
        }
        if let index = values.firstIndex(where: { !$0.isFinite }) {
            throw VolumeField3DError.nonFiniteUpload(resource: component.rawValue, index: index)
        }
        let staging = try makeStagingBuffer(operation: "upload")
        let destination = staging.contents().assumingMemoryBound(to: Float.self)
        let floatsPerRow = stagingLayout.bytesPerRow / MemoryLayout<Float>.stride
        let floatsPerImage = stagingLayout.bytesPerImage / MemoryLayout<Float>.stride
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    let sourceIndex = (z * height + y) * width + x
                    let destinationIndex = z * floatsPerImage + y * floatsPerRow + x
                    destination[destinationIndex] = values[sourceIndex]
                }
            }
        }

        let blit = try makeBlitEncoder(command: command, operation: "staged upload")
        blit.copy(
            from: staging,
            sourceOffset: 0,
            sourceBytesPerRow: stagingLayout.bytesPerRow,
            sourceBytesPerImage: stagingLayout.bytesPerImage,
            sourceSize: MTLSize(width: width, height: height, depth: depth),
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
    }

    /// Encodes a full-volume clear into both generations using the production kernel.
    func encodeClear(command: MTLCommandBuffer, pipeline: MTLComputePipelineState) throws {
        let extent = MTLSize(width: width, height: height, depth: depth)
        let threads = Fluid3DDispatch.threadsPerThreadgroup(for: pipeline)
        for (generation, texture) in [("ping", ping), ("pong", pong)] {
            guard let encoder = command.makeComputeCommandEncoder() else {
                throw VolumeField3DError.encoderUnavailable(
                    operation: "\(component.rawValue) \(generation) clear"
                )
            }
            encoder.label = "3D \(component.rawValue) \(generation) clear"
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(texture, index: 0)
            encoder.dispatchThreads(extent, threadsPerThreadgroup: threads)
            encoder.endEncoding()
        }
    }

    /// Encodes a private-texture to shared-buffer copy. Keep the returned buffer
    /// alive until the command buffer completes, then call `decodeReadback`.
    func encodeReadback(from texture: MTLTexture, command: MTLCommandBuffer) throws -> MTLBuffer {
        try validateOwned(texture)
        let buffer = try makeStagingBuffer(operation: "readback")
        let blit = try makeBlitEncoder(command: command, operation: "staged readback")
        blit.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: depth),
            to: buffer,
            destinationOffset: 0,
            destinationBytesPerRow: stagingLayout.bytesPerRow,
            destinationBytesPerImage: stagingLayout.bytesPerImage
        )
        blit.endEncoding()
        return buffer
    }

    func decodeReadback(_ buffer: MTLBuffer) throws -> [Float] {
        guard buffer.length >= stagingLayout.totalBytes else {
            throw VolumeField3DError.invalidReadback(
                resource: component.rawValue,
                expectedByteCount: stagingLayout.totalBytes,
                actualByteCount: buffer.length
            )
        }
        let source = buffer.contents().assumingMemoryBound(to: Float.self)
        let floatsPerRow = stagingLayout.bytesPerRow / MemoryLayout<Float>.stride
        let floatsPerImage = stagingLayout.bytesPerImage / MemoryLayout<Float>.stride
        var result = Array(repeating: Float.zero, count: width * height * depth)
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    let sourceIndex = z * floatsPerImage + y * floatsPerRow + x
                    let destinationIndex = (z * height + y) * width + x
                    result[destinationIndex] = source[sourceIndex]
                }
            }
        }
        return result
    }

    private func validateOwned(_ texture: MTLTexture) throws {
        guard texture === ping || texture === pong else {
            throw VolumeField3DError.textureNotOwned(resource: "3D \(component.rawValue) field")
        }
    }

    private func makeStagingBuffer(operation: String) throws -> MTLBuffer {
        guard let buffer = metal.device.makeBuffer(
            length: stagingLayout.totalBytes,
            options: .storageModeShared
        ) else {
            throw VolumeField3DError.stagingBufferAllocationFailed(
                resource: "3D \(component.rawValue) \(operation)",
                byteCount: stagingLayout.totalBytes
            )
        }
        buffer.label = "3D \(component.rawValue) \(operation) staging"
        return buffer
    }

    private static func makeStagingLayout(
        width: Int,
        height: Int,
        depth: Int,
        device: MTLDevice,
        resource: String
    ) throws -> StagingLayout {
        guard width > 0, height > 0, depth > 0 else {
            throw VolumeField3DError.stagingSizeOverflow(resource: resource)
        }
        let pixelBytes = MemoryLayout<Float>.stride
        let rawRow = try checkedProduct(width, pixelBytes, resource: resource)
        let deviceAlignment = max(1, device.minimumLinearTextureAlignment(for: .r32Float))
        let divisor = greatestCommonDivisor(pixelBytes, deviceAlignment)
        let alignmentProduct = (deviceAlignment / divisor).multipliedReportingOverflow(by: pixelBytes)
        guard !alignmentProduct.overflow else {
            throw VolumeField3DError.stagingSizeOverflow(resource: resource)
        }
        let alignment = alignmentProduct.partialValue
        let remainder = rawRow % alignment
        let row: Int
        if remainder == 0 {
            row = rawRow
        } else {
            let rounded = rawRow.addingReportingOverflow(alignment - remainder)
            guard !rounded.overflow else {
                throw VolumeField3DError.stagingSizeOverflow(resource: resource)
            }
            row = rounded.partialValue
        }
        let image = try checkedProduct(row, height, resource: resource)
        let total = try checkedProduct(image, depth, resource: resource)
        return StagingLayout(bytesPerRow: row, bytesPerImage: image, totalBytes: total)
    }

    private static func checkedProduct(_ first: Int, _ second: Int, resource: String) throws -> Int {
        let result = first.multipliedReportingOverflow(by: second)
        guard !result.overflow, result.partialValue > 0 else {
            throw VolumeField3DError.stagingSizeOverflow(resource: resource)
        }
        return result.partialValue
    }

    private static func checkedProduct(_ first: Int, _ second: Int, _ third: Int, resource: String) throws -> Int {
        try checkedProduct(checkedProduct(first, second, resource: resource), third, resource: resource)
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return max(1, a)
    }
}

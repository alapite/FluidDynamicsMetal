import Foundation
import Metal
import simd

private enum Fluid3DHarnessError: Error, CustomStringConvertible {
    case usage(String)
    case assertion(String)
    case commandBuffer(String)
    case library(String)

    var description: String {
        switch self {
        case .usage(let message), .assertion(let message), .commandBuffer(let message), .library(let message):
            return message
        }
    }
}

@main
@MainActor
private struct Fluid3DChecks {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Fluid3DHarnessError.assertion(message) }
    }

    static func command(_ metal: MetalDevice, _ encode: (MTLCommandBuffer) throws -> Void) throws {
        let buffer = metal.newCommandBuffer()
        try encode(buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        guard buffer.status == .completed else {
            throw Fluid3DHarnessError.commandBuffer("Metal command failed: \(String(describing: buffer.error))")
        }
    }

    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 3 else {
            throw Fluid3DHarnessError.usage(
                "usage: test_fluid3d <fresh-default.metallib> <reference-directory> <storage-abi>"
            )
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Fluid3DHarnessError.library("Metal device unavailable; production GPU tests cannot run")
        }
        let libraryURL = URL(fileURLWithPath: arguments[0])
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(URL: libraryURL)
        } catch {
            throw Fluid3DHarnessError.library(
                "Could not load production metallib at \(libraryURL.path): \(error)"
            )
        }
        let metal = MetalDevice(device: device, library: library)
        let fixture = arguments[2]
        guard fixture == "storage-abi" || fixture == "advection-boundaries" else {
            throw Fluid3DHarnessError.usage("unknown fixture selector: \(fixture)")
        }
        let result: [String: Any]
        if fixture == "storage-abi" {
            result = try storageAndABI(device: device, metal: metal)
        } else {
            result = try advectionAndBoundaries(
                device: device,
                metal: metal,
                referenceDirectory: URL(fileURLWithPath: arguments[1], isDirectory: true)
            )
        }
        try emit(result)
    }

    private static func advectionAndBoundaries(
        device: MTLDevice,
        metal: MetalDevice,
        referenceDirectory: URL
    ) throws -> [String: Any] {
        let manifestURL = referenceDirectory.appendingPathComponent("advection-manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        guard let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              (manifest["schemaVersion"] as? Int) == 1,
              (manifest["contractHash"] as? String) == "a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b",
              let tolerance = manifest["tolerance"] as? [String: Double],
              let absoluteTolerance = tolerance["absolute"],
              let relativeTolerance = tolerance["relative"],
              let fixtures = manifest["cases"] as? [[String: Any]] else {
            throw Fluid3DHarnessError.assertion("Invalid or mismatched advection CPU-oracle manifest")
        }

        let expectedNames: Set<String> = [
            "zero_uniform", "positive_x", "negative_x", "positive_y", "negative_y",
            "positive_z", "negative_z", "combined_xyz", "combined_xyz_mixed",
            "wall_edge_corner", "production_mixed",
        ]
        let actualNames = Set(fixtures.compactMap { $0["name"] as? String })
        try require(actualNames == expectedNames, "Advection oracle case set changed: \(actualNames)")

        var totalCompared = 0
        var maximumAbsoluteError = 0.0
        var caseReports: [[String: Any]] = []
        for fixture in fixtures {
            guard let name = fixture["name"] as? String,
                  let grid = fixture["grid"] as? [String: Any],
                  let nx = grid["nx"] as? Int,
                  let ny = grid["ny"] as? Int,
                  let nz = grid["nz"] as? Int,
                  let h = grid["h"] as? Double,
                  let dt = grid["dt"] as? Double,
                  let filename = fixture["file"] as? String,
                  let byteCount = fixture["byteCount"] as? Int,
                  let descriptors = fixture["arrays"] as? [[String: Any]] else {
                throw Fluid3DHarnessError.assertion("Malformed advection fixture in CPU-oracle manifest")
            }
            try require(grid["xFastest"] as? Bool == true, "\(name) does not declare x-fastest arrays")
            if name == "production_mixed" {
                try require(nx == 64 && ny == 64 && nz == 64, "Production fixture grid is not 64 cubed")
            } else {
                try require(nx == 8 && ny == 7 && nz == 6, "Asymmetric fixture grid changed for \(name)")
            }

            let payloadURL = referenceDirectory.appendingPathComponent(filename)
            let payload = try Data(contentsOf: payloadURL)
            try require(payload.count == byteCount, "\(name) payload byte count mismatch")
            var reference: [String: [Double]] = [:]
            for descriptor in descriptors {
                guard let fieldName = descriptor["name"] as? String,
                      let count = descriptor["elementCount"] as? Int,
                      let offsetElements = descriptor["offsetElements"] as? Int,
                      let shape = descriptor["shape"] as? [Int] else {
                    throw Fluid3DHarnessError.assertion("Malformed array descriptor in \(name)")
                }
                let shapeCount = shape.reduce(1, *)
                try require(shapeCount == count, "\(name)/\(fieldName) shape/count mismatch")
                try require(!reference.keys.contains(fieldName), "Duplicate \(fieldName) in \(name)")
                reference[fieldName] = try decodeLittleEndianDoubles(
                    payload, offsetElements: offsetElements, count: count
                )
            }
            let expectedFields: Set<String> = [
                "u_input", "v_input", "w_input", "dye_input",
                "u_advected", "v_advected", "w_advected", "dye_advected",
            ]
            try require(Set(reference.keys) == expectedFields, "\(name) array set changed: \(reference.keys)")
            for values in reference.values {
                try require(values.allSatisfy(\.isFinite), "\(name) CPU reference contains NaN or infinity")
            }

            let configuration = try FluidSimulation3DConfiguration.fixture(
                nx: nx, ny: ny, nz: nz, h: Float(h), dt: Float(dt)
            )
            let simulation = try FluidSimulation3D(metal: metal, configuration: configuration)
            // Each upload owns a blit encoder, so encode all four into one command buffer.
            let commandBuffer = metal.newCommandBuffer()
            try simulation.u.encodeUpload(reference["u_input"]!.map(Float.init),
                                          to: simulation.u.ping, command: commandBuffer)
            try simulation.v.encodeUpload(reference["v_input"]!.map(Float.init),
                                          to: simulation.v.ping, command: commandBuffer)
            try simulation.w.encodeUpload(reference["w_input"]!.map(Float.init),
                                          to: simulation.w.ping, command: commandBuffer)
            try simulation.dye.encodeUpload(reference["dye_input"]!.map(Float.init),
                                            to: simulation.dye.ping, command: commandBuffer)
            try simulation.encodeAdvection(command: commandBuffer)
            let uBuffer = try simulation.u.encodeReadback(from: simulation.u.ping, command: commandBuffer)
            let vBuffer = try simulation.v.encodeReadback(from: simulation.v.ping, command: commandBuffer)
            let wBuffer = try simulation.w.encodeReadback(from: simulation.w.ping, command: commandBuffer)
            let dyeBuffer = try simulation.dye.encodeReadback(from: simulation.dye.ping, command: commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard commandBuffer.status == .completed else {
                throw Fluid3DHarnessError.commandBuffer(
                    "\(name) advection command failed: \(String(describing: commandBuffer.error))"
                )
            }

            let actual: [String: [Float]] = [
                "u_advected": try simulation.u.decodeReadback(uBuffer),
                "v_advected": try simulation.v.decodeReadback(vBuffer),
                "w_advected": try simulation.w.decodeReadback(wBuffer),
                "dye_advected": try simulation.dye.decodeReadback(dyeBuffer),
            ]
            var caseMaximumError = 0.0
            for fieldName in ["u_advected", "v_advected", "w_advected", "dye_advected"] {
                let actualValues = actual[fieldName]!
                let referenceValues = reference[fieldName]!
                try require(actualValues.count == referenceValues.count,
                            "\(name)/\(fieldName) element count mismatch")
                for index in referenceValues.indices {
                    let actualValue = Double(actualValues[index])
                    let expectedValue = referenceValues[index]
                    try require(actualValue.isFinite && expectedValue.isFinite,
                                "\(name)/\(fieldName) nonfinite at x-fastest index \(index)")
                    let error = abs(actualValue - expectedValue)
                    let limit = absoluteTolerance + relativeTolerance * abs(expectedValue)
                    try require(error <= limit,
                                "\(name)/\(fieldName) mismatch at x-fastest index \(index): "
                                + "actual=\(actualValue) expected=\(expectedValue) error=\(error) limit=\(limit)")
                    caseMaximumError = max(caseMaximumError, error)
                    totalCompared += 1
                }
            }

            let wallFlux = try exactWallZeros(
                u: actual["u_advected"]!, v: actual["v_advected"]!, w: actual["w_advected"]!,
                nx: nx, ny: ny, nz: nz, label: name
            )
            let dye = actual["dye_advected"]!
            try require(dye.allSatisfy { $0 >= 0 && $0 <= 1 }, "\(name) dye escaped [0, 1]")
            if name == "zero_uniform" {
                try require(dye.allSatisfy { abs($0 - 0.375) <= 2e-6 },
                            "Zero-flow uniform dye decayed or changed")
            }
            if let expectedWall = fixture["maxWallNormalValue"] as? Double {
                try require(expectedWall == 0 && wallFlux == 0,
                            "\(name) normal wall faces are not exactly zero")
            }
            maximumAbsoluteError = max(maximumAbsoluteError, caseMaximumError)
            caseReports.append([
                "name": name,
                "grid": [nx, ny, nz],
                "comparedValues": actual.values.reduce(0) { $0 + $1.count },
                "maxAbsoluteError": caseMaximumError,
                "maxWallNormalValue": wallFlux,
                "dyeMinimum": dye.min() ?? 0,
                "dyeMaximum": dye.max() ?? 0,
                "finite": true,
            ])
        }
        totalCompared = caseReports.reduce(0) { $0 + (($1["comparedValues"] as? Int) ?? 0) }
        try require(totalCompared > 0, "No production advection values were compared")
        return [
            "passed": true,
            "fixture": "advection-boundaries",
            "device": device.name,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "contractHash": manifest["contractHash"]!,
            "cases": caseReports,
            "comparedValues": totalCompared,
            "maxAbsoluteError": maximumAbsoluteError,
            "absoluteTolerance": absoluteTolerance,
            "relativeTolerance": relativeTolerance,
            "finite": true,
        ]
    }

    private static func decodeLittleEndianDoubles(
        _ data: Data,
        offsetElements: Int,
        count: Int
    ) throws -> [Double] {
        let byteOffset = offsetElements.multipliedReportingOverflow(by: MemoryLayout<UInt64>.stride)
        let byteCount = count.multipliedReportingOverflow(by: MemoryLayout<UInt64>.stride)
        guard !byteOffset.overflow, !byteCount.overflow,
              byteOffset.partialValue >= 0,
              byteOffset.partialValue + byteCount.partialValue <= data.count else {
            throw Fluid3DHarnessError.assertion("CPU reference array exceeds its fixture payload")
        }
        return data.withUnsafeBytes { raw in
            (0..<count).map { index in
                let bits = UInt64(littleEndian: raw.loadUnaligned(
                    fromByteOffset: byteOffset.partialValue + index * MemoryLayout<UInt64>.stride,
                    as: UInt64.self
                ))
                return Double(bitPattern: bits)
            }
        }
    }

    private static func exactWallZeros(
        u: [Float], v: [Float], w: [Float], nx: Int, ny: Int, nz: Int, label: String
    ) throws -> Float {
        var maximum = Float.zero
        for z in 0..<nz {
            for y in 0..<ny {
                for x in [0, nx] {
                    let value = u[(z * ny + y) * (nx + 1) + x]
                    try require(value.isFinite && value == 0, "\(label) u wall face is not exactly zero")
                    maximum = max(maximum, abs(value))
                }
            }
        }
        for z in 0..<nz {
            for y in [0, ny] {
                for x in 0..<nx {
                    let value = v[(z * (ny + 1) + y) * nx + x]
                    try require(value.isFinite && value == 0, "\(label) v wall face is not exactly zero")
                    maximum = max(maximum, abs(value))
                }
            }
        }
        for z in [0, nz] {
            for y in 0..<ny {
                for x in 0..<nx {
                    let value = w[(z * ny + y) * nx + x]
                    try require(value.isFinite && value == 0, "\(label) w wall face is not exactly zero")
                    maximum = max(maximum, abs(value))
                }
            }
        }
        return maximum
    }

    private static func storageAndABI(device: MTLDevice, metal: MetalDevice) throws -> [String: Any] {
        let grid = try FluidSimulation3DConfiguration.fixture(nx: 8, ny: 7, nz: 6)
        let production = FluidSimulation3DConfiguration.production
        try require(production.nx == 64 && production.ny == 64 && production.nz == 64,
                    "Production 3D grid must remain fixed at 64 cubed")
        try expectConfigurationFailure(nx: 0, ny: 7, nz: 6, dt: 1.0 / 60.0)
        try expectConfigurationFailure(nx: 8, ny: 7, nz: 6, dt: .nan)
        try expectConfigurationFailure(nx: 8, ny: 7, nz: 6, h: Float.leastNonzeroMagnitude, dt: 1.0 / 60.0)
        try expectConfigurationFailure(nx: 8, ny: 7, nz: 6, h: .greatestFiniteMagnitude, dt: 1.0 / 60.0)
        try require(Fluid3DUniforms.abiIsValid, "Swift uniform ABI size, alignment, or offsets changed")
        try expectTextureAllocationFailure(grid: grid, metal: metal)

        let abiInput = Fluid3DUniforms(
            grid: SIMD4<UInt32>(8, 7, 6, 0x1020_3040),
            scale: SIMD4<Float>(0.125, 1.0 / 60.0, 8.0, 0.375),
            output: SIMD4<UInt32>(13, 11, 9, 0x5060_7080)
        )
        let abiResult = try gpuABIRoundTrip(abiInput, device: device, metal: metal)
        try require(abiResult == abiInput, "Swift/Metal 48-byte uniform round-trip changed a lane")

        let clearPipeline: MTLComputePipelineState
        do {
            clearPipeline = try metal.createComputePipeline(computeFunctionName: "fluid3DClear")
        } catch {
            throw Fluid3DHarnessError.library("Missing production clear pipeline fluid3DClear: \(error)")
        }
        try expectMissingPipelineFailure(metal)

        let expectedExtents: [VolumeField3D.Component: (Int, Int, Int)] = [
            .cell: (8, 7, 6),
            .u: (9, 7, 6),
            .v: (8, 8, 6),
            .w: (8, 7, 7),
        ]
        var comparedValues = 0
        var rowAlignments: [String: Int] = [:]
        for component in [VolumeField3D.Component.cell, .u, .v, .w] {
            let field = try VolumeField3D(grid: grid, component: component, metal: metal)
            let (width, height, depth) = expectedExtents[component]!
            try require(field.width == width && field.height == height && field.depth == depth,
                        "\(component.rawValue) extent mismatch: \(field.width)x\(field.height)x\(field.depth)")
            for (label, texture) in [("ping", field.ping), ("pong", field.pong)] {
                try require(texture.textureType == .type3D, "\(component.rawValue) \(label) is not a 3D texture")
                try require(texture.pixelFormat == .r32Float, "\(component.rawValue) \(label) is not r32Float")
                try require(texture.storageMode == .private, "\(component.rawValue) \(label) is not private storage")
                try require(texture.width == width && texture.height == height && texture.depth == depth,
                            "\(component.rawValue) \(label) Metal extent mismatch")
                try require(texture.usage.contains(.shaderRead) && texture.usage.contains(.shaderWrite),
                            "\(component.rawValue) \(label) usage must allow shader read/write")
            }
            let originalPing = field.ping
            let originalPong = field.pong
            field.swap()
            try require(field.ping === originalPong && field.pong === originalPing,
                        "\(component.rawValue) ping/pong swap did not exchange generations")
            field.swap()
            try require(field.ping === originalPing && field.pong === originalPong,
                        "\(component.rawValue) ping/pong swap did not restore generations")
            let layout = field.stagingLayout
            let requiredAlignment = max(4, device.minimumLinearTextureAlignment(for: .r32Float))
            try require(layout.bytesPerRow >= width * MemoryLayout<Float>.stride,
                        "\(component.rawValue) staging row is shorter than its pixels")
            try require(layout.bytesPerRow % requiredAlignment == 0,
                        "\(component.rawValue) row stride ignores device alignment \(requiredAlignment)")
            try require(layout.bytesPerImage == layout.bytesPerRow * height,
                        "\(component.rawValue) image stride omits the padded row stride")
            try require(layout.totalBytes == layout.bytesPerImage * depth,
                        "\(component.rawValue) staging allocation omits a depth plane")
            rowAlignments[component.rawValue] = layout.bytesPerRow

            let ramp = makeIndexRamp(width: width, height: height, depth: depth, component: component)
            let readbacks = try roundTrip(field: field, values: ramp, metal: metal)
            try compareExactly(readbacks.ping, ramp, label: "\(component.rawValue) ping all-plane ramp")
            try compareExactly(readbacks.pong, ramp, label: "\(component.rawValue) pong all-plane ramp")
            comparedValues += ramp.count * 2

            let cleared = try clearAndRead(field: field, pipeline: clearPipeline, metal: metal)
            try require(cleared.ping.allSatisfy { $0 == 0 } && cleared.pong.allSatisfy { $0 == 0 },
                        "\(component.rawValue) clear must cover every ping/pong voxel")
            comparedValues += cleared.ping.count + cleared.pong.count
        }

        return [
            "passed": true,
            "fixture": "storage-abi",
            "device": device.name,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "grid": [grid.nx, grid.ny, grid.nz],
            "productionGrid": [production.nx, production.ny, production.nz],
            "uniformStride": MemoryLayout<Fluid3DUniforms>.stride,
            "uniformAlignment": MemoryLayout<Fluid3DUniforms>.alignment,
            "uniformOffsets": [
                MemoryLayout<Fluid3DUniforms>.offset(of: \.grid)!,
                MemoryLayout<Fluid3DUniforms>.offset(of: \.scale)!,
                MemoryLayout<Fluid3DUniforms>.offset(of: \.output)!,
            ],
            "stagingBytesPerRow": rowAlignments,
            "exactComparedValues": comparedValues,
            "finite": true,
        ]
    }

    private static func gpuABIRoundTrip(
        _ input: Fluid3DUniforms,
        device: MTLDevice,
        metal: MetalDevice
    ) throws -> Fluid3DUniforms {
        var sourceValue = input
        let length = MemoryLayout<Fluid3DUniforms>.stride
        guard let source = device.makeBuffer(
            bytes: &sourceValue, length: length, options: .storageModeShared
        ), let destination = device.makeBuffer(length: length, options: .storageModeShared) else {
            throw Fluid3DHarnessError.library("Unable to allocate 48-byte ABI fixture buffers")
        }
        let pipeline: MTLComputePipelineState
        do {
            pipeline = try metal.createComputePipeline(computeFunctionName: "fluid3DABIRoundTrip")
        } catch {
            throw Fluid3DHarnessError.library("Missing production ABI pipeline fluid3DABIRoundTrip: \(error)")
        }
        try command(metal) { buffer in
            guard let encoder = buffer.makeComputeCommandEncoder() else {
                throw Fluid3DHarnessError.library("Unable to create ABI round-trip encoder")
            }
            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(source, offset: 0, index: 0)
            encoder.setBuffer(destination, offset: 0, index: 1)
            encoder.dispatchThreads(
                MTLSize(width: 1, height: 1, depth: 1),
                threadsPerThreadgroup: Fluid3DDispatch.threadsPerThreadgroup(for: pipeline)
            )
            encoder.endEncoding()
        }
        return destination.contents().assumingMemoryBound(to: Fluid3DUniforms.self).pointee
    }

    private static func expectMissingPipelineFailure(_ metal: MetalDevice) throws {
        do {
            _ = try metal.createComputePipeline(computeFunctionName: "fluid3DIntentionallyMissingFixture")
            throw Fluid3DHarnessError.assertion("Missing shader function silently created a pipeline")
        } catch let MetalDeviceError.failedToCreateFunction(name) {
            try require(name == "fluid3DIntentionallyMissingFixture",
                        "Missing pipeline error lost its function name: \(name)")
        }
    }

    private static func expectConfigurationFailure(
        nx: Int,
        ny: Int,
        nz: Int,
        h: Float = 1,
        dt: Float
    ) throws {
        do {
            _ = try FluidSimulation3DConfiguration.fixture(nx: nx, ny: ny, nz: nz, h: h, dt: dt)
            throw Fluid3DHarnessError.assertion("Invalid 3D grid/timestep configuration was accepted")
        } catch FluidSimulation3DError.invalidConfiguration {
            return
        }
    }

    private static func expectTextureAllocationFailure(
        grid: FluidSimulation3DConfiguration,
        metal: MetalDevice
    ) throws {
        do {
            _ = try VolumeField3D(
                grid: grid,
                component: .cell,
                metal: metal,
                textureFactory: { _ in nil }
            )
            throw Fluid3DHarnessError.assertion("Failed 3D allocation was replaced by a fallback field")
        } catch VolumeField3DError.textureAllocationFailed(let resource) {
            try require(resource.contains("cell"), "Allocation error lost its field name: \(resource)")
        }
    }

    private static func roundTrip(
        field: VolumeField3D,
        values: [Float],
        metal: MetalDevice
    ) throws -> (ping: [Float], pong: [Float]) {
        var pingReadback: MTLBuffer!
        var pongReadback: MTLBuffer!
        try command(metal) { commandBuffer in
            try field.encodeUpload(values, to: field.ping, command: commandBuffer)
            let blit = try field.makeBlitEncoder(command: commandBuffer, operation: "ping-to-pong fixture copy")
            blit.copy(from: field.ping, to: field.pong)
            blit.endEncoding()
            pingReadback = try field.encodeReadback(from: field.ping, command: commandBuffer)
            pongReadback = try field.encodeReadback(from: field.pong, command: commandBuffer)
        }
        return (try field.decodeReadback(pingReadback), try field.decodeReadback(pongReadback))
    }

    private static func clearAndRead(
        field: VolumeField3D,
        pipeline: MTLComputePipelineState,
        metal: MetalDevice
    ) throws -> (ping: [Float], pong: [Float]) {
        var pingReadback: MTLBuffer!
        var pongReadback: MTLBuffer!
        try command(metal) { commandBuffer in
            try field.encodeClear(command: commandBuffer, pipeline: pipeline)
            pingReadback = try field.encodeReadback(from: field.ping, command: commandBuffer)
            pongReadback = try field.encodeReadback(from: field.pong, command: commandBuffer)
        }
        return (try field.decodeReadback(pingReadback), try field.decodeReadback(pongReadback))
    }

    private static func makeIndexRamp(
        width: Int,
        height: Int,
        depth: Int,
        component: VolumeField3D.Component
    ) -> [Float] {
        var values: [Float] = []
        values.reserveCapacity(width * height * depth)
        let componentOffset = Float([.cell, .u, .v, .w].firstIndex(of: component)! * 100_000)
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    values.append(componentOffset + Float(x + 100 * y + 10_000 * z))
                }
            }
        }
        return values
    }

    private static func compareExactly(_ actual: [Float], _ expected: [Float], label: String) throws {
        try require(actual.count == expected.count, "\(label) element count mismatch")
        for index in expected.indices {
            try require(actual[index].isFinite && actual[index] == expected[index],
                        "\(label) mismatch at x-fastest index \(index): \(actual[index]) vs \(expected[index])")
        }
    }

    private static func emit(_ result: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw Fluid3DHarnessError.assertion("Could not encode fixture result JSON")
        }
        print("FLUID3D_RESULT=\(text)")
    }
}

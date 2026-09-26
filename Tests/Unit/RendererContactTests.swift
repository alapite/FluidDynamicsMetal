import MetalKit
import XCTest

final class RendererContactTests: XCTestCase {
    func testUniformLayoutMatchesMetalBufferData() {
        XCTAssertEqual(MemoryLayout<StaticData>.alignment, 16)
        XCTAssertEqual(MemoryLayout<StaticData>.stride, 208)
        XCTAssertEqual(MemoryLayout<StaticData>.size, 208)
        XCTAssertEqual(MemoryLayout<StaticData>.offset(of: \.positions), 0)
        XCTAssertEqual(MemoryLayout<StaticData>.offset(of: \.impulses), 80)
        XCTAssertEqual(MemoryLayout<StaticData>.offset(of: \.impulseScalar), 160)
        XCTAssertEqual(MemoryLayout<StaticData>.offset(of: \.offsets), 168)
        XCTAssertEqual(MemoryLayout<StaticData>.offset(of: \.screenSize), 176)
        XCTAssertEqual(MemoryLayout<StaticData>.offset(of: \.inkRadius), 184)
        XCTAssertEqual(MemoryLayout<StaticData>.offset(of: \.tuning), 192)
    }

    func testContactTupleContainsTenTightlyPackedVectors() {
        XCTAssertEqual(MemoryLayout<SIMD2<Float>>.stride, 8)
        XCTAssertEqual(MemoryLayout<ContactTuple>.alignment, 8)
        XCTAssertEqual(MemoryLayout<ContactTuple>.size, 80)
        XCTAssertEqual(MemoryLayout<ContactTuple>.stride, 80)
        let tuple: ContactTuple = (SIMD2(1, -1), SIMD2(2, -2), SIMD2(3, -3), SIMD2(4, -4), SIMD2(5, -5),
                                   SIMD2(6, -6), SIMD2(7, -7), SIMD2(8, -8), SIMD2(9, -9), SIMD2(10, -10))
        withUnsafeBytes(of: tuple) { bytes in
            for index in 0..<10 {
                XCTAssertEqual(bytes.load(fromByteOffset: index * 8, as: SIMD2<Float>.self),
                               SIMD2(Float(index + 1), -Float(index + 1)))
            }
        }
    }

    func testMouseOriginIsOneContactAndMovementIsMeasuredPerFrame() throws {
        var mouse = MouseInputState()
        XCTAssertNil(mouse.contactForFrame())
        mouse.update(position: .zero)
        let origin = try XCTUnwrap(mouse.contactForFrame())
        XCTAssertEqual(origin.position, .zero)
        XCTAssertEqual(origin.impulse, .zero)

        var data = emptyData()
        Renderer.writeContacts([origin], tuning: SimulationTuning(), radius: 150, to: &data)
        withUnsafeBytes(of: data.positions) { bytes in
            let slots = bytes.bindMemory(to: SIMD2<Float>.self)
            XCTAssertEqual(slots.filter { $0 != .zero }.count, 1)
        }

        mouse.update(position: SIMD2(2, 3))
        mouse.update(position: SIMD2(5, 7))
        XCTAssertEqual(mouse.contactForFrame()?.impulse, SIMD2(5, 7))
        XCTAssertEqual(mouse.contactForFrame()?.impulse, .zero, "Holding still must not repeat the impulse")
        mouse.update(position: .zero)
        XCTAssertEqual(mouse.contactForFrame()?.impulse, SIMD2(-5, -7))
    }

    func testMouseReleaseAndRebaseDiscardPreviousFramePosition() {
        var mouse = MouseInputState()
        mouse.update(position: SIMD2(2, 3))
        XCTAssertEqual(mouse.contactForFrame()?.impulse, .zero)
        mouse.update(position: nil)
        XCTAssertNil(mouse.contactForFrame())
        mouse.update(position: SIMD2(50, 60))
        XCTAssertEqual(mouse.contactForFrame()?.impulse, .zero)

        // Resize, pause and inactivity all use this same clear operation.
        mouse.clear()
        XCTAssertNil(mouse.contactForFrame())
        mouse.update(position: SIMD2(100, 120))
        XCTAssertEqual(mouse.contactForFrame()?.impulse, .zero)
    }

    private func emptyData() -> StaticData {
        let zero = SIMD2<Float>.zero
        return StaticData(positions: (zero, zero, zero, zero, zero, zero, zero, zero, zero, zero),
                          impulses: (zero, zero, zero, zero, zero, zero, zero, zero, zero, zero),
                          impulseScalar: zero, offsets: zero, screenSize: SIMD2<Float>(16, 16),
                          inkRadius: 150, tuning: simd_float4(0.998, 0.4, 0, 0))
    }

    func testNextMovementUsesCurrentIndependentForceAndDye() {
        let contact = FluidContact(position: SIMD2<Float>(8, 8), impulse: SIMD2<Float>(2, -3))
        var tuning = SimulationTuning()
        var data = emptyData()

        tuning.setPosition(0, for: .force)
        Renderer.writeContacts([contact], tuning: tuning, radius: 75, to: &data)
        XCTAssertEqual(data.positions.0.x, 8)
        XCTAssertEqual(data.impulses.0.x, 0)
        XCTAssertEqual(data.impulseScalar.x, 0.8, accuracy: 0.00001)
        XCTAssertEqual(data.inkRadius, 75)

        tuning.setPosition(0.75, for: .force)
        tuning.setPosition(0, for: .dye)
        Renderer.writeContacts([contact], tuning: tuning, radius: 75, to: &data)
        XCTAssertEqual(data.impulses.0.x, 3, accuracy: 0.00001)
        XCTAssertEqual(data.impulses.0.y, -4.5, accuracy: 0.00001)
        XCTAssertEqual(data.impulseScalar.x, 0)
    }

    func testEleventhContactGetsSameTuningInSecondBatch() {
        let contacts = (1...11).map { index in
            FluidContact(position: SIMD2<Float>(Float(index), 8), impulse: SIMD2<Float>(Float(index), 0))
        }
        var tuning = SimulationTuning()
        tuning.setPosition(0.75, for: .force)
        tuning.setPosition(0.25, for: .dye)
        let batches = Renderer.contactBatches(contacts)
        XCTAssertEqual(batches.map { $0.count }, [10, 1])

        var data = emptyData()
        Renderer.writeContacts(batches[0], tuning: tuning, radius: 150, to: &data)
        XCTAssertEqual(data.positions.9.x, 10)
        XCTAssertEqual(data.impulses.9.x, 15)
        XCTAssertEqual(data.impulseScalar.x, 0.5)

        Renderer.writeContacts(batches[1], tuning: tuning, radius: 150, to: &data)
        XCTAssertEqual(data.positions.0.x, 11)
        XCTAssertEqual(data.impulses.0.x, 16.5)
        XCTAssertEqual(data.impulseScalar.x, 0.5)
        XCTAssertEqual(data.positions.1.x, 0, "The next batch must clear old contacts")
        XCTAssertEqual(data.impulses.9.x, 0, "The next batch must clear old impulses")
    }

    func testOriginContactAndEmptyFrameKeepTheirDistinctSentinels() {
        var data = emptyData()
        Renderer.writeContacts([FluidContact(position: .zero, impulse: .zero)],
                               tuning: SimulationTuning(), radius: 150, to: &data)
        XCTAssertEqual(data.positions.0.x, 0.01, accuracy: 0.00001)
        XCTAssertEqual(data.impulseScalar.x, 0.8, accuracy: 0.00001)

        Renderer.writeContacts([], tuning: SimulationTuning(), radius: 150, to: &data)
        XCTAssertEqual(data.positions.0.x, 0)
        XCTAssertEqual(data.impulseScalar.x, 0)
    }
}

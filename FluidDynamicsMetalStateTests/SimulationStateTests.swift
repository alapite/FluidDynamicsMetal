import XCTest

final class SimulationStateTests: XCTestCase {
    func testFieldCycleAndPause() {
        var state = SimulationState()
        XCTAssertEqual(state.field, .density)
        XCTAssertTrue(state.shouldAdvance)
        state.togglePause()
        XCTAssertFalse(state.shouldAdvance)
        for field in [DisplayField.pressure, .velocity, .vorticity, .density] {
            state.nextField()
            XCTAssertEqual(state.field, field)
            XCTAssertFalse(state.shouldAdvance)
        }
        state.nextField()
        state.togglePause()
        XCTAssertTrue(state.shouldAdvance)
        XCTAssertEqual(state.field, .pressure)
    }

    func testInactivePreservesUserChoiceAndField() {
        var running = SimulationState()
        running.nextField()
        running.resignActive()
        XCTAssertFalse(running.shouldAdvance)
        running.becomeActive()
        XCTAssertTrue(running.shouldAdvance)
        XCTAssertEqual(running.field, .pressure)

        running.togglePause()
        running.resignActive()
        running.becomeActive()
        XCTAssertTrue(running.userPaused)
        XCTAssertFalse(running.shouldAdvance)
        XCTAssertEqual(running.field, .pressure)
    }

    func testTuningDefaultsBoundsAndNonFinite() {
        var tuning = SimulationTuning()
        XCTAssertEqual(tuning.force, 1)
        XCTAssertEqual(tuning.dye, 0.8)
        XCTAssertEqual(tuning.radius, 150)
        XCTAssertEqual(tuning.swirl, 0.4)
        XCTAssertEqual(tuning.retention, 0.998)
        XCTAssertEqual(tuning.pressureIterations, 40)
        tuning.force = -1; XCTAssertEqual(tuning.force, 0)
        tuning.force = 3; XCTAssertEqual(tuning.force, 2)
        tuning.dye = -1; XCTAssertEqual(tuning.dye, 0)
        tuning.dye = 3; XCTAssertEqual(tuning.dye, 2)
        tuning.radius = 0; XCTAssertEqual(tuning.radius, 1)
        tuning.radius = 500; XCTAssertEqual(tuning.radius, 400)
        tuning.swirl = -1; XCTAssertEqual(tuning.swirl, 0)
        tuning.swirl = 3; XCTAssertEqual(tuning.swirl, 2)
        tuning.retention = -1; XCTAssertEqual(tuning.retention, 0)
        tuning.retention = 3; XCTAssertEqual(tuning.retention, 1)
        tuning.pressureIterations = 0; XCTAssertEqual(tuning.pressureIterations, 1)
        tuning.pressureIterations = 100; XCTAssertEqual(tuning.pressureIterations, 80)
        tuning.force = .nan; XCTAssertEqual(tuning.force, 1)
        tuning.dye = .infinity; XCTAssertEqual(tuning.dye, 0.8)
        tuning.radius = -.infinity; XCTAssertEqual(tuning.radius, 150)
        tuning.swirl = .nan; XCTAssertEqual(tuning.swirl, 0.4)
        tuning.retention = .infinity; XCTAssertEqual(tuning.retention, 0.998)
    }

    func testResetOnlyChangesTuning() {
        var state = SimulationState()
        state.nextField()
        state.togglePause()
        state.tuning.force = 2
        state.tuning.pressureIterations = 80
        state.resetTuning()
        XCTAssertEqual(state.tuning.force, 1)
        XCTAssertEqual(state.tuning.pressureIterations, 40)
        XCTAssertEqual(state.field, .pressure)
        XCTAssertTrue(state.userPaused)
    }
}

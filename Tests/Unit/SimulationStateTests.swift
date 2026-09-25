import XCTest

final class SimulationStateTests: XCTestCase {
    func testSliderPositionsPreserveOriginalDefaultsAndBounds() {
        let tuning = SimulationTuning()
        XCTAssertEqual(tuning.position(for: .force), 0.5, accuracy: 0.00001)
        XCTAssertEqual(tuning.position(for: .dye), 0.4, accuracy: 0.00001)
        XCTAssertEqual(tuning.position(for: .swirl), 0.2, accuracy: 0.00001)
        XCTAssertEqual(tuning.position(for: .fade), 0.17, accuracy: 0.00001)
        var changed = tuning
        for control in TuningControl.allCases {
            changed.setPosition(-1, for: control)
            XCTAssertEqual(changed.position(for: control), 0, accuracy: 0.00001)
            changed.setPosition(2, for: control)
            XCTAssertEqual(changed.position(for: control), 1, accuracy: 0.00001)
            changed.setPosition(0.63, for: control)
            XCTAssertEqual(changed.position(for: control), 0.63, accuracy: 0.0001)
        }
        XCTAssertEqual(changed.force, 1.26, accuracy: 0.0001)
        XCTAssertEqual(changed.dye, 1.26, accuracy: 0.0001)
        XCTAssertEqual(changed.swirl, 1.26, accuracy: 0.0001)
        changed.setPosition(.nan, for: .force)
        XCTAssertEqual(changed.force, 1)
    }

    func testFadeMapsContinuousPositionsAcrossOriginalDetent() {
        var tuning = SimulationTuning()
        for (position, retention) in [(Float(0), Float(0.9995)), (0.17, 0.998), (1, 0.9905), (0.085, 0.99875), (0.585, 0.99425)] {
            tuning.setPosition(position, for: .fade)
            XCTAssertEqual(tuning.retention, retention, accuracy: 0.00001)
            XCTAssertEqual(tuning.position(for: .fade), position, accuracy: 0.0001)
        }
        tuning.setPosition(.infinity, for: .fade)
        XCTAssertEqual(tuning.retention, 0.998)
    }

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

    func testDirectFieldSelectionPreservesPauseAndInactivity() {
        var state = SimulationState()
        state.selectField(.vorticity)
        XCTAssertEqual(state.field, .vorticity)
        XCTAssertTrue(state.shouldAdvance)

        state.togglePause()
        state.selectField(.pressure)
        state.selectField(.pressure)
        XCTAssertEqual(state.field, .pressure)
        XCTAssertTrue(state.userPaused)
        XCTAssertFalse(state.shouldAdvance)

        state.resignActive()
        state.selectField(.velocity)
        XCTAssertEqual(state.field, .velocity)
        XCTAssertTrue(state.inactive)
        state.becomeActive()
        XCTAssertEqual(state.field, .velocity)
        XCTAssertTrue(state.userPaused)
        XCTAssertFalse(state.shouldAdvance)
        state.nextField()
        XCTAssertEqual(state.field, .vorticity)
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

    func testPauseChangedDuringInactivityIsStillTheUserChoiceOnReturn() {
        var state = SimulationState()
        state.resignActive()
        state.nextField()
        state.togglePause()
        XCTAssertFalse(state.shouldAdvance)
        state.becomeActive()
        XCTAssertEqual(state.field, .pressure)
        XCTAssertTrue(state.userPaused)
        XCTAssertFalse(state.shouldAdvance)
        state.togglePause()
        XCTAssertTrue(state.shouldAdvance)
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
        state.tuning.dye = 0
        state.tuning.radius = 400
        state.tuning.swirl = 2
        state.tuning.retention = 0
        state.tuning.pressureIterations = 80
        state.resetTuning()
        XCTAssertEqual(state.tuning.force, 1)
        XCTAssertEqual(state.tuning.dye, 0.8)
        XCTAssertEqual(state.tuning.radius, 150)
        XCTAssertEqual(state.tuning.swirl, 0.4)
        XCTAssertEqual(state.tuning.retention, 0.998)
        XCTAssertEqual(state.tuning.pressureIterations, 40)
        XCTAssertEqual(state.field, .pressure)
        XCTAssertTrue(state.userPaused)
    }
}

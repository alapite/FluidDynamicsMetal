import XCTest
import simd

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
        for (position, retention) in [(Float(0), Float(1)), (0.17, 0.998), (1, 0.9905), (0.085, 0.999), (0.585, 0.99425)] {
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

    func testQueuedStepsAndInactivity() {
        var state = SimulationState()
        XCTAssertFalse(state.requestSingleStep())
        state.togglePause()
        for _ in 0..<31 { XCTAssertTrue(state.requestSingleStep()) }
        for expected in 1...31 { XCTAssertTrue(state.consumeStep()); XCTAssertEqual(state.stepCount, expected); XCTAssertTrue(state.userPaused) }
        XCTAssertFalse(state.consumeStep())
        state.requestSingleStep(); state.resignActive()
        XCTAssertEqual(state.pendingSteps, 0); XCTAssertFalse(state.consumeStep())
        state.becomeActive(); XCTAssertTrue(state.userPaused)
        state.requestSingleStep(); state.togglePause()
        XCTAssertEqual(state.pendingSteps, 0)
    }
    func testLessonTransitionsAndPreferences() {
        var state = SimulationState()
        state.tuning.force = 1.7; state.selectField(.pressure)
        state.setDisplayOptions(DisplayOptions(arrows: true, particles: false, trails: true))
        let saved = state.tuning
        state.selectMode(.experiment(.advection))
        XCTAssertTrue(state.resetting); XCTAssertFalse(state.requestSingleStep())
        state.finishReset()
        XCTAssertTrue(state.userPaused); XCTAssertEqual(state.stepCount, 0)
        XCTAssertEqual(state.adjustment, .speed(.normal)); XCTAssertEqual(state.field, .density)
        XCTAssertEqual(state.tuning, .lesson)
        state.selectField(.velocity); state.setDisplayOptions(DisplayOptions())
        XCTAssertTrue(state.setExperimentAdjustment(.speed(.fast))); state.finishReset()
        state.requestSingleStep(); state.consumeStep(); state.beginReset(); state.finishReset()
        XCTAssertEqual(state.stepCount, 0); XCTAssertEqual(state.pendingSteps, 0)
        XCTAssertEqual(state.adjustment, .speed(.fast)); XCTAssertEqual(state.field, .velocity)
        XCTAssertEqual(state.displayOptions, DisplayOptions())
        state.selectMode(.experiment(.interactingVortices)); state.finishReset()
        XCTAssertEqual(state.adjustment, .rotation(.same)); XCTAssertEqual(state.field, .vorticity)
        XCTAssertFalse(state.setExperimentAdjustment(.speed(.fast)))
        state.selectMode(.freePlay); state.finishReset()
        XCTAssertTrue(state.shouldAdvance); XCTAssertEqual(state.tuning, saved)
        XCTAssertEqual(state.field, .pressure); XCTAssertTrue(state.displayOptions.arrows)
        state.togglePause(); state.requestSingleStep(); state.beginReset(); state.finishReset()
        XCTAssertTrue(state.userPaused); XCTAssertEqual(state.pendingSteps, 0); XCTAssertEqual(state.tuning, saved)
    }
    func testThreeDEntryAndExactQueuedSteps() {
        var state = SimulationState()
        state.selectMode(.experiment(.advection)); state.finishReset()
        XCTAssertTrue(state.requestSingleStep())

        state.selectMode(.dyeAdvection3D)
        XCTAssertTrue(state.mode.is3D)
        XCTAssertTrue(state.mode.isLesson)
        XCTAssertNil(state.mode.experiment)
        XCTAssertTrue(state.resetting)
        XCTAssertTrue(state.userPaused)
        XCTAssertEqual(state.stepCount, 0)
        XCTAssertEqual(state.pendingSteps, 0)
        XCTAssertFalse(state.acceptsInput)
        state.finishReset()
        XCTAssertTrue(state.canStep)

        for _ in 0..<31 { XCTAssertTrue(state.requestSingleStep()) }
        XCTAssertEqual(state.pendingSteps, 31)
        for expected in 1...31 {
            XCTAssertTrue(state.consumeStep())
            XCTAssertEqual(state.stepCount, expected)
            XCTAssertTrue(state.userPaused)
        }
        XCTAssertEqual(state.pendingSteps, 0)
        XCTAssertFalse(state.consumeStep())
        XCTAssertEqual(state.stepCount, 31)
    }

    func testThreeDReselectAndRestartResetPausedTransport() {
        var state = SimulationState()
        state.selectMode(.dyeAdvection3D); state.finishReset()
        XCTAssertTrue(state.requestSingleStep())
        XCTAssertTrue(state.consumeStep())
        XCTAssertEqual(state.stepCount, 1)
        XCTAssertTrue(state.requestSingleStep())
        XCTAssertEqual(state.pendingSteps, 1)

        state.selectMode(.dyeAdvection3D)
        XCTAssertTrue(state.resetting)
        XCTAssertTrue(state.userPaused)
        XCTAssertEqual(state.stepCount, 0)
        XCTAssertEqual(state.pendingSteps, 0)
        state.finishReset()
        XCTAssertTrue(state.canStep)

        XCTAssertTrue(state.requestSingleStep())
        XCTAssertTrue(state.consumeStep())
        state.requestSingleStep()
        state.beginReset()
        XCTAssertTrue(state.resetting)
        XCTAssertTrue(state.userPaused)
        XCTAssertEqual(state.stepCount, 0)
        XCTAssertEqual(state.pendingSteps, 0)
        state.finishReset()
        XCTAssertTrue(state.canStep)
    }

    func testThreeDInactivityPreservesManualIntent() {
        var state = SimulationState()
        state.selectMode(.dyeAdvection3D); state.finishReset()
        XCTAssertTrue(state.requestSingleStep())
        state.resignActive()
        XCTAssertEqual(state.pendingSteps, 0)
        XCTAssertFalse(state.consumeStep())
        state.becomeActive()
        XCTAssertTrue(state.userPaused)
        XCTAssertFalse(state.shouldAdvance)
        XCTAssertEqual(state.stepCount, 0)

        state.togglePause()
        XCTAssertTrue(state.shouldAdvance)
        XCTAssertFalse(state.userPaused)
        state.resignActive()
        XCTAssertFalse(state.shouldAdvance)
        state.becomeActive()
        XCTAssertTrue(state.shouldAdvance)
        XCTAssertFalse(state.userPaused)
        XCTAssertEqual(state.stepCount, 0)

        state.togglePause()
        state.resignActive()
        state.becomeActive()
        XCTAssertTrue(state.userPaused)
        XCTAssertFalse(state.shouldAdvance)
    }

    func testThreeDFieldActionsAreNoOps() {
        var state = SimulationState()
        state.selectField(.pressure)
        let options = DisplayOptions(arrows: true, particles: false, trails: true)
        state.setDisplayOptions(options)
        state.selectMode(.dyeAdvection3D); state.finishReset()
        let field = state.field

        state.nextField()
        state.selectField(.velocity)
        state.setDisplayOptions(DisplayOptions())

        XCTAssertEqual(state.field, field)
        XCTAssertEqual(state.displayOptions, options)
        XCTAssertNil(state.adjustment)
        XCTAssertFalse(state.setExperimentAdjustment(.speed(.fast)))
        XCTAssertNil(state.adjustment)
    }

    func testThreeDReturnPreservesTwoDPreferences() {
        var state = SimulationState()
        state.tuning.force = 1.7
        state.selectField(.pressure)
        let options = DisplayOptions(arrows: true, particles: false, trails: true)
        state.setDisplayOptions(options)
        let tuning = state.tuning

        state.selectMode(.dyeAdvection3D); state.finishReset()
        state.selectMode(.freePlay); state.finishReset()
        XCTAssertTrue(state.shouldAdvance)
        XCTAssertEqual(state.tuning, tuning)
        XCTAssertEqual(state.field, .pressure)
        XCTAssertEqual(state.displayOptions, options)

        state.selectMode(.dyeAdvection3D); state.finishReset()
        state.selectMode(.experiment(.interactingVortices)); state.finishReset()
        XCTAssertTrue(state.userPaused)
        XCTAssertEqual(state.field, .vorticity)
        XCTAssertEqual(state.adjustment, .rotation(.same))
        XCTAssertEqual(state.tuning, .lesson)
        XCTAssertEqual(state.displayOptions, DisplayOptions(arrows: true))
        XCTAssertFalse(state.acceptsInput)
    }

    func testLessonOverlayDefaultsAndOverrides() {
        let presets: [(ExperimentID, DisplayOptions)] = [
            (.advection, DisplayOptions(particles: true, trails: true)),
            (.interactingVortices, DisplayOptions(arrows: true)),
            (.dyeStretching, DisplayOptions())
        ]
        var state = SimulationState()
        let override = DisplayOptions(arrows: true, particles: true, trails: true)
        for (lesson, expected) in presets {
            state.selectMode(.experiment(lesson))
            state.finishReset()
            XCTAssertEqual(state.displayOptions, expected)
            state.selectField(.pressure)
            state.setDisplayOptions(override)
            state.beginReset()
            state.finishReset()
            XCTAssertEqual(state.displayOptions, override)
            XCTAssertEqual(state.field, .pressure)
            XCTAssertTrue(state.setExperimentAdjustment(lesson.choices[0]))
            state.finishReset()
            XCTAssertEqual(state.displayOptions, override)
            XCTAssertEqual(state.field, .pressure)
        }
    }

    func testStartingOutlineGeometry() {
        let advection = ExperimentRecipes.startingOutline(.advection)
        let radius = ExperimentRecipes.advectionDyeSigma * sqrt(2 * log(Float(2)))
        XCTAssertFalse(advection.isEmpty)
        for segment in advection {
            XCTAssertEqual(simd_distance(segment.start, ExperimentRecipes.advectionDye), radius, accuracy: 0.00015)
        }

        let stretching = ExperimentRecipes.startingOutline(.dyeStretching)
        let stroke = stretching.map(\.start)
        let size = ExperimentRecipes.gridSize
        let seed = ExperimentRecipes.seed(.dyeStretching, adjustment: .strength(.normal)).dye
        func halfMaximumBounds(_ samples: [Float]) -> ClosedRange<Float> {
            let first = samples.firstIndex { $0 >= 0.5 }!
            let last = samples.lastIndex { $0 >= 0.5 }!
            func crossing(after index: Int) -> Float {
                let fraction = (0.5 - samples[index]) / (samples[index + 1] - samples[index])
                return (Float(index) + 0.5 + fraction) / Float(size)
            }
            return crossing(after: first - 1)...crossing(after: last)
        }
        let horizontal = halfMaximumBounds((0..<size).map { seed[size * (size / 2) + $0].x })
        let vertical = halfMaximumBounds((0..<size).map { seed[size * $0 + size / 2].x })
        XCTAssertEqual(stroke.map(\.x).min() ?? 0, horizontal.lowerBound, accuracy: 0.000001)
        XCTAssertEqual(stroke.map(\.x).max() ?? 0, horizontal.upperBound, accuracy: 0.000001)
        XCTAssertEqual(stroke.map(\.y).min() ?? 0, vertical.lowerBound, accuracy: 0.000001)
        XCTAssertEqual(stroke.map(\.y).max() ?? 0, vertical.upperBound, accuracy: 0.000001)
        XCTAssertTrue(ExperimentRecipes.startingOutline(.interactingVortices).isEmpty)
        for segments in [advection, stretching] {
            XCTAssertTrue(segments.first?.start == segments.last?.end)
            for (current, next) in zip(segments, segments.dropFirst()) {
                XCTAssertEqual(current.end, next.start)
                XCTAssertEqual(current.distanceAtStart + simd_distance(current.start, current.end),
                               next.distanceAtStart, accuracy: 0.000001)
            }
        }
    }

    func testStartingOutlineVisibilityAndPersistence() {
        var state = SimulationState()
        XCTAssertFalse(state.offersStartingOutline)
        state.selectMode(.experiment(.advection))
        state.finishReset()
        XCTAssertTrue(state.offersStartingOutline)
        XCTAssertFalse(state.setStartingOutline(true))

        XCTAssertTrue(state.requestSingleStep())
        XCTAssertTrue(state.consumeStep())
        XCTAssertTrue(state.setStartingOutline(true))
        XCTAssertEqual(state.stepCount, 1)
        XCTAssertTrue(state.showsStartingOutline)
        XCTAssertTrue(state.requestSingleStep())
        XCTAssertTrue(state.consumeStep())
        XCTAssertTrue(state.showsStartingOutline)

        state.togglePause()
        XCTAssertFalse(state.canToggleStartingOutline)
        XCTAssertFalse(state.showsStartingOutline)
        state.togglePause()
        XCTAssertTrue(state.showsStartingOutline)
        state.selectField(.pressure)
        XCTAssertFalse(state.offersStartingOutline)
        XCTAssertFalse(state.showsStartingOutline)
        state.selectField(.density)
        XCTAssertTrue(state.showsStartingOutline)

        state.beginReset()
        state.finishReset()
        XCTAssertTrue(state.startingOutlineEnabled)
        XCTAssertFalse(state.showsStartingOutline)
        XCTAssertFalse(state.canToggleStartingOutline)
        XCTAssertTrue(state.setExperimentAdjustment(.speed(.fast)))
        state.finishReset()
        XCTAssertTrue(state.startingOutlineEnabled)
        state.togglePause()
        for _ in 0..<SimulationState.lessonSteps { XCTAssertTrue(state.consumeStep()) }
        XCTAssertTrue(state.complete)
        XCTAssertTrue(state.canToggleStartingOutline)
        XCTAssertTrue(state.showsStartingOutline)
        XCTAssertTrue(state.setStartingOutline(false))
        XCTAssertTrue(state.setStartingOutline(true))

        state.selectMode(.experiment(.dyeStretching))
        state.finishReset()
        XCTAssertTrue(state.offersStartingOutline)
        XCTAssertFalse(state.startingOutlineEnabled)
        state.selectMode(.experiment(.interactingVortices))
        state.finishReset()
        state.selectField(.density)
        XCTAssertFalse(state.offersStartingOutline)
    }

    func testCompletionAndRestart() {
        var state = SimulationState()
        state.selectMode(.experiment(.dyeStretching)); state.finishReset(); state.togglePause()
        for _ in 0..<600 { XCTAssertTrue(state.consumeStep()) }
        XCTAssertTrue(state.complete); XCTAssertTrue(state.userPaused)
        XCTAssertFalse(state.requestSingleStep()); XCTAssertFalse(state.consumeStep())
        state.togglePause(); XCTAssertTrue(state.userPaused)
        state.beginReset(); state.finishReset(); XCTAssertFalse(state.complete); XCTAssertTrue(state.canStep)
    }
    func testThreeDLessonCompletesAtItsOwnLength() {
        XCTAssertNil(SimulationMode.freePlay.lessonStepLimit, "Free Play must have no lesson limit")
        for lesson in ExperimentID.allCases {
            XCTAssertEqual(SimulationMode.experiment(lesson).lessonStepLimit, 600, "2D lesson \(lesson) must stay at 600")
        }
        let n = SimulationState.threeDLessonSteps
        XCTAssertTrue([1200, 1500, 1800].contains(n), "3D lesson length must be a preregistered choice")
        XCTAssertEqual(SimulationMode.dyeAdvection3D.lessonStepLimit, n)

        // Running past the 2D length.
        var running = SimulationState()
        running.selectMode(.dyeAdvection3D); running.finishReset(); running.togglePause()
        for _ in 0..<600 { XCTAssertTrue(running.consumeStep()) }
        XCTAssertFalse(running.complete, "3D lesson must not complete at 600")
        XCTAssertEqual(running.status, "Step 600")
        XCTAssertTrue(running.shouldAdvance, "3D lesson must keep advancing after 600")

        // The N-1 boundary.
        for _ in 600..<(n - 1) { XCTAssertTrue(running.consumeStep()) }
        running.togglePause()
        XCTAssertEqual(running.stepCount, n - 1); XCTAssertTrue(running.userPaused)
        XCTAssertEqual(running.status, "Step \(n - 1)")
        XCTAssertTrue(running.requestSingleStep(), "one step at N-1 must be accepted")
        XCTAssertFalse(running.requestSingleStep(), "a second queued step at N-1 must be refused")
        XCTAssertTrue(running.consumeStep())
        XCTAssertEqual(running.stepCount, n)
        XCTAssertTrue(running.complete, "3D lesson must complete at N"); XCTAssertTrue(running.userPaused)
        XCTAssertEqual(running.status, "Experiment complete. Restart to compare.")
        XCTAssertFalse(running.requestSingleStep()); XCTAssertFalse(running.consumeStep())
        running.togglePause(); XCTAssertTrue(running.userPaused, "pause toggle must not resume a completed lesson")
        running.beginReset(); running.finishReset()
        XCTAssertEqual(running.stepCount, 0); XCTAssertEqual(running.status, "Step 0")
        XCTAssertFalse(running.complete); XCTAssertTrue(running.canStep)

        // 2D lessons still accept exactly one queued step at 599.
        var twoD = SimulationState()
        twoD.selectMode(.experiment(.dyeStretching)); twoD.finishReset(); twoD.togglePause()
        for _ in 0..<599 { XCTAssertTrue(twoD.consumeStep()) }
        twoD.togglePause()
        XCTAssertTrue(twoD.requestSingleStep(), "2D at 599 accepts one step")
        XCTAssertFalse(twoD.requestSingleStep(), "2D at 599 refuses a second queued step")
        XCTAssertTrue(twoD.consumeStep()); XCTAssertTrue(twoD.complete); XCTAssertEqual(twoD.stepCount, 600)

        // Free Play never completes.
        var free = SimulationState()
        free.selectMode(.freePlay); free.finishReset()
        for _ in 0..<2000 { XCTAssertTrue(free.consumeStep()) }
        XCTAssertFalse(free.complete, "Free Play must never complete")
    }
    func testRetentionIsolation() {
        var tuning = SimulationTuning()
        tuning.setPosition(1, for: .fade)
        XCTAssertEqual(tuning.velocityRetention, 0.998); XCTAssertEqual(tuning.dyeRetention, 0.9905, accuracy: 0.00001)
        tuning.setPosition(0, for: .damping)
        XCTAssertEqual(tuning.velocityRetention, 1); XCTAssertEqual(tuning.dyeRetention, 0.9905, accuracy: 0.00001)
        tuning.setPosition(.nan, for: .damping); XCTAssertEqual(tuning.velocityRetention, 0.998)
    }
    func testRecipeConstantsAndDeterministicSeeds() {
        XCTAssertEqual(ExperimentRecipes.gridSize, 256)
        XCTAssertEqual(ExperimentRecipes.phaseLength, 120)
        for lesson in ExperimentID.allCases {
            let a = ExperimentRecipes.seed(lesson, adjustment: lesson.defaultAdjustment)
            let b = ExperimentRecipes.seed(lesson, adjustment: lesson.defaultAdjustment)
            XCTAssertEqual(a.velocity, b.velocity); XCTAssertEqual(a.dye, b.dye)
            XCTAssertTrue(a.dye.contains { $0.x > 0.5 })
            XCTAssertTrue(a.velocity.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            for i in 0..<512 { XCTAssertEqual(a.velocity[i], .zero) }
        }
        XCTAssertEqual(ExperimentRecipes.stirringAmplitude(step: 240, adjustment: .strength(.strong)), 0)
        XCTAssertGreaterThan(ExperimentRecipes.stirringAmplitude(step: 60, adjustment: .strength(.strong)), 0.059)
    }
}

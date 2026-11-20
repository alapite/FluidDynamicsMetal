---
phase: 07-first-3d-fluid-vertical-slice
plan: 10
subsystem: rendering
tags: [metal, mtkview, appkit, nspanel, xctest, gap-closure]

requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: UAT gap G-07-5 root cause (.planning/debug/2d-lesson-switch-canvas-not-reset.md) and the Command-M side finding from the G-07-4 diagnosis
provides:
  - Paused 2D presentation and paused 2D Step drain routed through MTKView.draw() with a presentation-only flag
  - Headless MTKView spy regression for drawable reads outside draw() and exact paused-step consumption
  - Real-window macOS UI regressions for direct lesson switching / paused Step and for panel-key Command-M
  - SimulationControlsPanel that forwards Minimize to the canvas window
affects: [07-11, 07-12, 07-13, phase-07-verification]

actuals:
  tokens: 4416
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Paused presentation goes through MTKView.draw() when the renderer is the delegate; delegate-less headless fixtures keep drawPresentationOnly"
    - "Headless MTKView subclass spy counts draw() calls and currentDrawable reads made outside draw()"

key-files:
  created: []
  modified:
    - Sources/Shared/Renderer.swift
    - Sources/macOS/RenderViewController.swift
    - Tests/Integration/test_educational_release.swift
    - Tests/UI/macOS/HUDUITests.swift

key-decisions:
  - "Route paused 2D redraws and the paused Step drain through view.draw() (not setNeedsDisplay) because MTKView retires its current drawable only at the end of draw()"
  - "A private drawingPresentationOnly flag makes the public draw(in:) entry take the no-advance path, so a presentation redraw can never consume a pending step or input"
  - "SimulationControlsPanel stays non-miniaturizable and forwards performMiniaturize to the canvas, reusing the existing willMiniaturize path (renderer.resignActive())"
  - "No inactive indicator was added: the panel is hidden while the app is inactive or the canvas is minimized, so an indicator would be invisible exactly when needed, and it would need a UI-SPEC copy decision"

patterns-established:
  - "Spy-based drawable-lifecycle regression: assert zero currentDrawable reads outside MTKView.draw() instead of relying on screenshots"

requirements-completed: [SIM-06, LES-06]

coverage:
  - id: D1
    description: "Direct paused 2D lesson switches and restart/field/option/reactivation/resize/available-rect redraws present through MTKView.draw() with zero drawable reads outside draw(), leaving step 0 with the lesson default field and adjustment"
    requirement: SIM-06
    verification:
      - kind: integration
        ref: "python3 -m unittest Tests.Integration.test_educational_release (PASS real renderer: paused 2D presentation via MTKView.draw())"
        status: pass
    human_judgment: false
  - id: D2
    description: "Each paused 2D Step advances exactly one step through MTKView.draw(); presentation-only redraws never consume a pending step"
    requirement: SIM-06
    verification:
      - kind: integration
        ref: "python3 -m unittest Tests.Integration.test_educational_release (3 paused Steps -> step 3, pending 0; pending Step survives selectField/setDisplayOptions/nextSlab and drains once)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Real-window Command-2/3/4/2 switching and two paused Steps visibly change the canvas"
    requirement: SIM-06
    verification:
      - kind: automated_ui
        ref: "Tests/UI/macOS/HUDUITests.swift#testDirectPausedLessonSwitchesRefreshCanvas"
        status: pass
    human_judgment: true
    rationale: "The UI test passed on the unchanged Renderer too (XCUITest screenshots do not reproduce the stale-drawable symptom on this host), so it is a regression guard, not proof of the fix; the user must re-observe direct lesson switching on a real display (07-12)"
  - id: D4
    description: "Window > Minimize is enabled while the controls panel is key and Command-M minimizes the canvas, ordering the panel out and freezing evolution"
    requirement: LES-06
    verification:
      - kind: automated_ui
        ref: "Tests/UI/macOS/HUDUITests.swift#testPanelKeyMinimizeMinimizesCanvas"
        status: pass
      - kind: automated_ui
        ref: "Tests/UI/macOS/HUDUITests.swift#testFloatingPanelReopensWithoutChangingState"
        status: pass
    human_judgment: false

duration: 57min
completed: 2026-11-20
status: complete
plan_head_before: cb321691277bac07e00c41f10d0f74d675abeb63
plan_head_after: 053eeede573ea6cb5179e18a1b4ef8cfe8f8952e
---

# Phase 7 Plan 10: Paused 2D presentation and panel Command-M Summary

**Paused 2D lesson selection, restart, resize, reactivation and Step now present through MTKView.draw() (fixing G-07-5's stale-drawable defect, proven by a headless MTKView spy), and Command-M works from the key Simulation Controls panel via a Minimize-forwarding NSPanel subclass.**

## Performance

- **Duration:** 57 min wall clock, of which about 25 min were a host-side UI hang (see Issues Encountered)
- **Started:** 2026-11-20T22:09:06Z
- **Completed:** 2026-11-20T23:06Z
- **Tasks:** 2 (Task 1 tracer with RED/GREEN, Task 2 RED/GREEN)
- **Files modified:** 4

## Accomplishments

- Root cause fixed: since 08-03 `Renderer.redrawIfPaused()` and the paused Step drain read `view.currentDrawable` outside an MTKView draw cycle. MTKView caches that drawable until the end of its next real `draw()`, so every later paused redraw rendered correct pixels into an already-presented drawable. Both paths now call `view.draw()` when the renderer is the delegate, so the read happens inside `draw()`.
- `drawingPresentationOnly` forces the public `draw(in:)` delegate entry onto the no-advance path during a presentation redraw, so lesson selection, restart, field/option change, resize and reactivation can never consume a pending step or input (D-16).
- Headless fixtures without a delegate keep the existing `drawPresentationOnly` fallback; 3D routing, the 2D solver, shader entry-point strings and the StaticData/BufferData layouts are untouched.
- `SimulationControlsPanel` forwards Window > Minimize (Command-M) to the miniaturizable, non-minimized canvas; the existing `willMiniaturizeNotification` observer then orders the panel out and calls `renderer.resignActive()`. The panel's style mask is unchanged.

## Task Commits

1. **Task 1: paused 2D presentation through MTKView.draw()** - RED `47e05f1` (test), GREEN `a685e1a` (fix)
2. **Task 2: Command-M from the controls panel** - RED `6802a59` (test), GREEN `053eeed` (feat)

**Plan metadata:** recorded in the docs(07-10) commit that adds this file.

## TDD record

### Task 1 RED (`47e05f1`)

- **Command:** `python3 -m unittest Tests.Integration.test_educational_release` against the unchanged Renderer (log `.build/07-10-red-spy.log`), exit 1 (child exit -5).
- **Failure message:** `Selecting paused lesson Dye carried by a flow did not present through MTKView.draw() (draw calls 0 -> 0)`.
- **Semantic assessment:** the target harness compiled, the new delegate-path block executed, and it failed on the planned assertion for the intended reason (the unfixed Renderer never calls `view.draw()` for a paused 2D selection; it reads the drawable via `drawPresentationOnly`). Not a build, load or fixture failure. The windowless spy view did invoke the delegate from `MTKView.draw()` in GREEN, so no hosting window was needed.
- **UI test pre-fix outcome:** `testDirectPausedLessonSwitchesRefreshCanvas` PASSED on the unchanged Renderer (14.8 s; log `.build/07-10-red-ui2.log`). An earlier first attempt failed only because it asserted panel text after closing the panel (test bug, fixed before the RED commit). The exported captures show the correct, distinct lesson image after each switch, so XCUITest screenshots do not reproduce the stale-drawable symptom on this host (a plausible, unverified reason is that synthesized events or screenshot capture retire MTKView's drawable between switches). The test is kept unweakened as a regression guard; the deterministic detector for G-07-5 is the headless spy.

### Task 1 GREEN (`a685e1a`)

- `python3 -m unittest Tests.Integration.test_educational_release`: OK in 43.4 s; prints `PASS real renderer: paused 2D presentation via MTKView.draw()` and `PASS: educational production engine`.
- `testDirectPausedLessonSwitchesRefreshCanvas`: passed, 14.7 s.

### Task 2 RED (`6802a59`)

- `testPanelKeyMinimizeMinimizesCanvas` failed on the unchanged controller at `Tests/UI/macOS/HUDUITests.swift:134`: `XCTAssertTrue failed - Window > Minimize must be enabled while the controls panel is key` (13.1 s; log `.build/07-10-red-minimize.log`). Semantic assessment: the planned assertion for the planned reason.

### Task 2 GREEN (`053eeed`)

- `testPanelKeyMinimizeMinimizesCanvas` (14.2 s) and `testFloatingPanelReopensWithoutChangingState` (7.4 s) both passed.

## Files Created/Modified

- `Sources/Shared/Renderer.swift` - `drawingPresentationOnly` flag, `redrawIfPaused` 2D delegate path via `view.draw()`, `scheduleStepDrain` routing for every paused mode, public `draw(in:)` presentation branch
- `Sources/macOS/RenderViewController.swift` - `SimulationControlsPanel` (Minimize forwarding and validation), panel construction and canvas-window wiring
- `Tests/Integration/test_educational_release.swift` - `PresentationSpyView` and the delegate-path assertions
- `Tests/UI/macOS/HUDUITests.swift` - `testDirectPausedLessonSwitchesRefreshCanvas`, `testPanelKeyMinimizeMinimizesCanvas`

## Decisions Made

See `key-decisions` above. The inactive indicator from the G-07-4 side finding was deliberately not added: the controls panel is hidden while the app is inactive or the canvas is minimized, so an indicator there would be invisible exactly when it is needed, and it would require a UI-SPEC copy decision.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] UI test asserted panel text after closing the panel**
- **Found during:** Task 1 (first RED run of `testDirectPausedLessonSwitchesRefreshCanvas`)
- **Issue:** The test read `stepCount` / `Step N` static texts, which live in the panel, after the panel had been closed for clean captures; the lookup failed.
- **Fix:** Removed those text assertions; the lesson-switch and Step checks rely on settled canvas captures, as the plan specifies.
- **Files modified:** Tests/UI/macOS/HUDUITests.swift
- **Verification:** Test runs to completion pre- and post-fix.
- **Committed in:** 47e05f1

---

**Total deviations:** 1 auto-fixed (1 test bug)
**Impact on plan:** No scope change.

### Execution-environment notes

- `master` is a protected/default branch per `git.base-branch`; the Step 0 guard would flag it. The dispatch states `branching_strategy=none` and that committing on master is expected, matching prior commits in this repository, so commits proceeded on master without changing any configuration.
- `requirements-completed` lists SIM-06 and LES-06 from the plan frontmatter, but `requirements.ready-ids` reports both blocked (sibling plans 07-11..07-13 declare gap closure for them) and project STATE keeps them pending manual acceptance, so `requirements.mark-complete` was not run.

## Issues Encountered

- **Host-side hang in two existing 3D failure UI tests.** In the full Mac suite, `testThreeDInitializationFailureRestoresTwoD` took 386.8 s (it passed) and `testThreeDTracerAndDepthPreparationFailuresRestoreTwoDAndRetry` never finished: clicking the "Continue in 2D" alert button was repeatedly blocked ("No monitors handled UI interruption" with about 12 Finder windows listed as interrupting elements). The suite was stopped at that point; all 22 UI tests that had completed passed, 25/25 state tests passed, and the two remaining Tuning UI tests passed when run on their own (7.8 s, 6.7 s; the pass count with the hanging test excluded is 24 of 25 UI tests). The hanging test was then retried alone on this source (same hang, killed at the 540 s guard) and on a temporary worktree of the pre-plan commit `cb32169` (same hang, killed at the 420 s guard, no pass/fail). The identical behavior on unchanged source indicates a host/desktop condition (Finder windows overlapping the alert), not this plan. That one test is therefore NOT verified for this plan and remains for the 07-13 matrix on a clean desktop. Logs: `.build/07-10-full-mac.log`, `.build/07-10-retry-remaining.log`.

## Verification Matrix

| Check | Result | Duration |
|-------|--------|----------|
| Mac build (no overrides) | BUILD SUCCEEDED | about 5 s incremental |
| iOS Simulator build (`generic/platform=iOS Simulator`) | BUILD SUCCEEDED | 8.1 s |
| `test_educational_release` RED / GREEN | exit 1 / OK | 14.7 s / 43.4 s |
| Focused integration set (`test_educational_release`, `test_renderer_correctness`, `test_fluid3d` steps_and_inactivity, transitions_and_failures, inspection_routing) | 9 tests OK | 208.6 s |
| Mac state tests | 25/25 | 0.4 s |
| Mac UI tests, full run | 22 passed before the host hang; 2 Tuning tests passed in a separate run; 1 test hung (see Issues) | about 28 min for the stopped run |
| iOS HUD suite, iPhone 17 Pro iOS 26.4 simulator (8393A81F-69D4-439E-AF8E-ED7665022800) | 11/11 | about 280 s |

No simulator retries were needed. Measured evidence artifacts are under `.build/07-10-*`; fixtures rewrote per-fixture evidence under `.build/fluid3d-evidence`, which 07-13 regenerates.

## Acceptance Criteria

- Task 1: pre-fix spy failure recorded, post-fix pass confirmed; `grep -c drawingPresentationOnly Sources/Shared/Renderer.swift` = 4 (>= 3); `grep -c PresentationSpyView Tests/Integration/test_educational_release.swift` = 2 (>= 2); `grep -c "func testDirectPausedLessonSwitchesRefreshCanvas"` = 1; separate RED (`47e05f1`) and GREEN (`a685e1a`) commits exist.
- Task 2: pre-fix failure recorded, both focused UI tests pass post-fix; `grep -c SimulationControlsPanel Sources/macOS/RenderViewController.swift` = 3 (>= 2); `grep -c "func testPanelKeyMinimizeMinimizesCanvas"` = 1; the installControls style mask is still `[.titled, .closable, .utilityWindow]`.

## Known Stubs

None.

## Threat Flags

None. The Renderer presentation change and the Minimize forwarder are the surfaces covered by T-07-23, T-07-24 and T-07-25; no new network, auth, file or schema surface was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 07-11 and then 07-12 (human re-observation of G-07-2 and G-07-5) and 07-13 (fresh evidence regeneration). The deterministic G-07-5 proof is the headless spy; the real-window UI test is a guard that also passed on the unchanged Renderer, so user re-observation on a real display in 07-12 is still the acceptance step.
- 07-13 should rerun `testThreeDTracerAndDepthPreparationFailuresRestoreTwoDAndRetry` on a clean desktop (no Finder windows overlapping alerts).

## Self-Check: PASSED

- Commits `47e05f1`, `a685e1a`, `6802a59`, `053eeed` verified as ancestors of HEAD.
- Modified files exist on disk; `commits: 4` measured from `plan_head_before..HEAD`.

---
*Phase: 07-first-3d-fluid-vertical-slice*
*Completed: 2026-11-20*

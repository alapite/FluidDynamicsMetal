---
phase: 07-first-3d-fluid-vertical-slice
plan: 16
subsystem: lesson-state
tags: [swift, simulation-state, lesson-length, xctest, ui-test, evidence-gate, uat-gap, g-07-2, tdd]

requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: 07-15 shipped recipe (seed speed 0.155, blob B3) and derivedLessonSteps 1200
provides:
  - SimulationMode.lessonStepLimit (nil Free Play, 600 for 2D lessons, SimulationState.threeDLessonSteps for 3D)
  - SimulationState.threeDLessonSteps = 1200
  - Evidence key threeDLesson.shippedLessonSteps and gate L1 (shipped equals derived) in Swift and Python
  - README, ROADMAP Phase 9 handoff, REQUIREMENTS acceptance note, dated 07/08 UI-SPEC amendments
affects: [07-17, 07-13, phase-09]

actuals:
  tasks: 3
  commits: 6

plan_head_before: 5787b3c
commits: 6

tech-stack:
  added: []
  patterns:
    - "One per-mode limit read by both completion and step queuing, instead of a global cap plus a special case"
    - "Shipped constant parsed from source and cross-checked against the evidence-derived value"

key-files:
  created:
    - .planning/phases/07-first-3d-fluid-vertical-slice/07-16-SUMMARY.md
  modified:
    - Sources/Shared/SimulationState.swift
    - Tests/Unit/SimulationStateTests.swift
    - Tests/Integration/test_inspection3d_state.swift
    - Tests/UI/macOS/HUDUITests.swift
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
    - README.md
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - .planning/phases/08-spatial-inspection/08-UI-SPEC.md
    - .planning/phases/07-first-3d-fluid-vertical-slice/07-UI-SPEC.md

key-decisions:
  - "N = 1200, read from the 07-15 FINAL evidence (derivedLessonSteps), not estimated."
  - "SimulationState.lessonSteps = 600 stays as the 2D value; the 3D value is a separate constant behind lessonStepLimit."
  - "LES-05 text, the Lesson convention and every requirement status are unchanged; Phase 9 must reconcile 600 vs 1200."

duration: approximately 45 min
completed: 2026-11-21
---

# Phase 7 Plan 16: Mode-specific 3D lesson length — Summary

**The 3D Dye Advection lesson now runs to 1200 steps, the length 07-15 measured to cover the full fade (step 300) and return (step 950). The 2D lessons still stop at 600, and Free Play never completes.**

## Accomplishments

- **Task 1 (RED `f0ab574`, GREEN `0f8e02e`):** `SimulationMode.lessonStepLimit` is now the single limit that `complete` and `requestSingleStep` read. `SimulationState.threeDLessonSteps = 1200`. Status text, consumeStep, togglePause, reset and both RenderViewControllers are unchanged. New tests:
  - `testThreeDLessonCompletesAtItsOwnLength` covers the per-mode limits, running past 600, the N-1 boundary, completion at N with the controls locked, restart, the 2D boundary at 599 and Free Play over 2000 steps.
  - `testThreeDLessonRunsPastTwoDLengthAndCompletes` runs the real Mac window: the counter goes past "Step 650", then reaches "Experiment complete. Restart to compare.", Step and Run are disabled, and Restart returns to "Step 0" with Step enabled.
  - The inspection-state harness now uses the 3D limit.
- **Task 2 (RED `d1571b0`, GREEN `9068e0a`):**
  - The evolution-visibility fixture emits `threeDLesson.shippedLessonSteps`, and gate L1 fails the aggregated assertion if it differs from derivedLessonSteps.
  - Python `_validate_shipped_lesson_length` parses `static let threeDLessonSteps` from source and requires it to equal both the emitted shipped value and the derived value.
  - `run_production_fixture` asserts it.
- **Task 3 (`0266b68`):**
  - README gains the 1200/600 sentence and the square-root brightness note.
  - The scoped-preview paragraph now defers the "complete teaching/completion contract (including reconciling the 3D lesson length with LES-05's 600 steps)".
  - The ROADMAP Phase 9 handoff line records seed speed 0.155 and the reason 0.17 was dropped.
  - The REQUIREMENTS acceptance note is added; LES-05 text is unchanged.
  - The dated "Square-root display transfer and 3D lesson-length amendment" is appended to 08-UI-SPEC (transfer rule, shipped legend, accessibility label and factual note) and to 07-UI-SPEC.

## Results

| Check | Result |
|---|---|
| Mac state tests | 26/26 pass |
| HUD testLessonCompletion (2D) | pass, 15.4 s |
| HUD testThreeDLessonRunsPastTwoDLengthAndCompletes | pass, 36.3 s |
| test_inspection3d_state | OK |
| Python L1, larger-blob and evidence-schema tests, plus a production rerun of evolution-visibility | 4/4 OK; real evidence validates `[]`, shippedLessonSteps 1200 |
| Task 3 verify command | VERIFY_OK, N=1200, S=0.155 |
| iOS Simulator build | succeeded |
| Full Mac `xcodebuild test` (state + HUD) | 26 state + 26 HUD, 0 failures (HUD run 1586 s) |
| test_educational_release | OK |
| UI-SPEC and REQUIREMENTS diffs | additions only |

## Task Commits

1. `f0ab574` test(07-16): require a mode-specific 3D lesson length past 600 steps (RED)
2. `0f8e02e` feat(07-16): complete the 3D lesson at its measured length (1200 steps)
3. `d1571b0` test(07-16): require shipped 3D lesson length to match source and evidence (RED)
4. `9068e0a` test(07-16): emit shippedLessonSteps and gate L1 so the 3D lesson length cannot drift (GREEN)
5. `0266b68` docs(07-16): record 1200-step 3D lesson, square-root display copy and Phase 9 handoff

## Deviations from Plan

- **Inline execution:** this plan was run inline by the orchestrator session at the user's request, not by a GSD executor.
- **Combined runner assertion:** the shipped-length check is added to the same `run_production_fixture` assertion as the 07-15 capture check, rather than as a separate assertion.

## Issues Encountered

None.

## Threat Flags

None. These are state-machine and test changes with no new inputs.

## Human review

The real-window test proves the mechanics only. Whether 1200 steps and the square-root display let the learner see the fade and return is judged by the user in 07-17, the blocking checkpoint.

## Next Phase Readiness

07-17, the blocking human review of the rebuilt Mac app, can run next, followed by 07-13.

## Self-Check: PASSED

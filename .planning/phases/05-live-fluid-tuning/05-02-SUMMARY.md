---
phase: 05-live-fluid-tuning
plan: 02
subsystem: ios-ui
tags: [uikit, ios-simulator, tuning, xcuittest]
requires:
  - phase: 05-live-fluid-tuning
    provides: Shared slider mapping and running-frame Metal tuning from 05-01
provides:
  - Native lower-trailing iOS tuning disclosure and four continuous sliders
  - A bounded single-scroll HUD preserving canvas touch exclusion
  - iPhone HUD regression checks for values, persistence, gestures and rotation
affects: [05-03, 06-quality-reset-accessibility]
tech-stack:
  added: []
  patterns: [one scroll view for the entire compact HUD, renderer state is the only solver value source]
key-files:
  created: []
  modified: [FluidDynamicsMetaliOS/RenderViewController.swift, FluidDynamicsMetaliOSUITests/HUDUITests.swift]
key-decisions:
  - "Reflow field rows before sizing the expanded HUD to 320 pt; preserve wide closed-HUD field layouts."
requirements-completed: [CTRL-02, CTRL-03, CTRL-04]
duration: 19 min
completed: 2026-09-25
---

# Phase 05 Plan 02: iOS live tuning HUD

**iPhone and iPad use the same four bounded renderer values through native sliders in their existing lower-trailing HUD.**

## Performance
- **Tasks:** 2/2
- **Files changed:** 2

## Accomplishments
- Show/Hide Tuning starts closed, retains slider positions and expanded state across canvas, pause, field selection and rotation.
- UI slider changes update the shared renderer immediately, and readable percentages reflect its state even while paused.
- One bounded scroll region keeps the field choices, Pause, disclosure and four tuning rows reachable in constrained landscape; HUD-origin gestures remain excluded by the existing touch filter.

## Task Commits
1. **Task 1: Working iOS tuning path** — `d04b6a8`
2. **Task 2: Compact layout and HUD regressions** — `cc842e9`

## Verification
- `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=8393A81F-69D4-439E-AF8E-ED7665022800' CODE_SIGNING_ALLOWED=NO`: iPhone 17 Pro/iOS 26.4, 6 UI tests passed, 0 failures (2026-09-25; xcresult `Test-FluidDynamicsMetaliOS-2026.09.25_20-30-16-+0100.xcresult`). Includes fresh-launch default readouts, Hide/Reopen persistence, outside-HUD shortcut, HUD double tap, landscape scroll reachability and Phase 4 regressions.
- `xcodebuild -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`: exited 0.
- `python3 -m unittest test_phase05_metal.py`: 1 GPU readback test passed after the iOS-only changes.
- An iPad Pro 13-inch (M5)/iOS 26.4 UI test attempt timed out during the simulator test run before producing a usable result. iPad runtime interaction remains NOT TESTED, not a pass.

## Deviations from Plan
- The iOS HUD uses a single scroll view for the whole expanded content in compact layouts instead of nesting field and tuning scrolls. Ordinary layouts fit the primary actions above the tuning rows without scrolling.

## Issues Encountered
- The first full simulator run timed out; a focused rerun followed by the full iPhone suite succeeded. iPad tests timed out twice without test results and remain for Plan 03 observation.

## Self-Check: PASSED
- Both files and task commits exist; iPhone UI tests, iOS build and shared GPU regression exited 0.

## Next Phase Readiness
- Both platforms expose the shared controls. Plan 03 must record real Mac/iPhone/iPad fluid observations and the unavailable iPad test outcome honestly.

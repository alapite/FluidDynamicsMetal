---
phase: 05-live-fluid-tuning
plan: 03
subsystem: verification
tags: [metal, appkit, uikit, xcuittest, live-observation]
requires:
  - phase: 05-live-fluid-tuning
    provides: Shared Mac/Metal and iOS HUD implementations from 05-01 and 05-02
provides:
  - Reproducible Mac and iPhone UI/state test, both-scheme build and numeric GPU evidence
  - User-approved Mac/iPhone/iPad live tuning and compact HUD observations
affects: [06-quality-reset-accessibility]
tech-stack:
  added: []
  patterns: [separate automated numeric results from attributed live observations]
key-files:
  created: [.planning/phases/05-live-fluid-tuning/05-TUNING-VERIFICATION.md]
  modified: [.planning/phases/05-live-fluid-tuning/05-VALIDATION.md, test_phase05_metal.swift]
key-decisions:
  - "Keep the iPad UI-test timeout and physical multitouch as NOT TESTED despite successful user-reported iPad live behavior."
requirements-completed: [CTRL-02, CTRL-03, CTRL-04]
duration: 6 min plus human checkpoint
completed: 2026-09-25
---

# Phase 05 Plan 03: Live tuning verification summary

**Numeric Metal readback and native UI tests are paired with the user's separately attributed live Mac, iPhone, and iPad approval.**

## Performance
- **Tasks:** 2/2, including the blocking human verification checkpoint.
- **Files changed:** 3.

## Accomplishments
- Recorded Mac state/HUD test results, independent Force/Dye splats, velocity/density retention, and no-contact Swirl GPU readback in `05-TUNING-VERIFICATION.md`.
- The user approved every live checklist item on all three available hosts: original-looking defaults, independent Force/Dye, ongoing Swirl/Fade, frozen paused slab, retained disclosure values, compact scroll reachability, and outside-HUD input.
- Updated `05-VALIDATION.md` using actual automated and human evidence; retained explicitly NOT TESTED physical multitouch and iPad UI automation.

## Task Commits
1. **Task 1: Run both app suites and prepare tuning observation evidence** — `4c8c9e8`.
2. **Task 2: Observe live tuning on Mac, iPhone and iPad** — `c3f4614`.

## Verification
- Mac: `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` — 13/13 passed (8 state, 5 UI), macOS 27 / arm64.
- Metal: `python3 -m unittest test_phase05_metal.py` — 1/1 passed using the freshly built Mac `default.metallib`; actual RG16F values and expected comparisons are in `05-TUNING-VERIFICATION.md`.
- iOS: `xcodebuild -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` exited 0; iPhone 17 Pro/iOS 26.4 `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=8393A81F-69D4-439E-AF8E-ED7665022800' CODE_SIGNING_ALLOWED=NO` passed 6/6 UI tests.
- iPad Pro M5/iOS 26.4 UI test command timed out (240 seconds; focused retry 180 seconds) without a passing result. The app launched on that simulator, and the user separately approved its live checklist. Physical iOS two-finger/concurrent touch and macOS 26 runtime remain prior non-blocking NOT TESTED items.

## Deviations from Plan
- iPad UI automation did not finish; kept the automated result NOT TESTED and relied only on the user's separately attributed live iPad observation for visual acceptance.

## Issues Encountered
- Simulator test infrastructure timed out on iPad without a usable result; iPhone UI, Mac UI/state, production GPU readback, and both app builds completed.

## Self-Check: PASSED
- Both task commits, the dated verification matrix, completed validation rows and the user's human-checkpoint response are present. Automated commands and their results are recorded independently.

## Next Phase Readiness
- Phase 5 goal evidence is ready for code review and phase-level verification. Phase 6 owns quality/resolution, reset and the final accessibility work.

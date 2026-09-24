---
phase: 02-modern-ios-parity
plan: 03
subsystem: verification
tags: [simulator, parity, ios26, macos]
requires:
  - phase: 02-modern-ios-parity
    provides: iOS 26 app and multi-contact input from plans 01 and 02
provides:
  - iPhone/iPad simulator launch and user-observed interaction evidence
  - Explicit untested device-only multi-touch and macOS 26 runtime cases
affects: [phase-03, milestone-closeout]
tech-stack:
  added: []
  patterns: [Separate process-launch evidence from observed GPU interaction]
key-files:
  created: [.planning/phases/02-modern-ios-parity/02-PARITY.md]
  modified: []
key-decisions:
  - "Mark the two-finger shortcut and device-only multi-touch as untested; no physical device test was performed."
patterns-established:
  - "Record device, OS, observed result and reference separately for each behavior."
requirements-completed: [PLAT-02, PLAT-03, SIM-01]
duration: 10 min
completed: 2026-09-24
---

# Phase 02 Plan 03: Simulator parity evidence summary

**Fresh iOS 26.4 builds launched on iPhone and iPad simulators; the user observed blue fluid, dragging, tapping and one-finger pause on both layouts.**

## Performance
- Started: 2026-09-24T20:54:45Z
- Completed: 2026-09-24T21:05:30Z
- Tasks: 2/2 (including human-verification checkpoint)
- Files created: 1

## Task Commits
- Task 1: `d98465c` — both-scheme build, built-bundle and fresh simulator launch evidence in `02-PARITY.md`.
- Task 2: `b369260` — user-observed simulator results and explicit untested rows in the same table.

## Verification
- `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build`: exit 0.
- `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build`: exit 0.
- `-showBuildSettings -json` identified `/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Build/Products/Debug-iphonesimulator/FluidDynamicsMetaliOS.app`; `MinimumOSVersion=26.0`, `default.metallib` present. Reinstalled this bundle onto both booted iOS 26.4 simulators; `simctl launch` returned PID 44273 (iPhone 17 Pro) and PID 44982 (iPad Pro 11-inch M5).
- The user opened the iOS scheme in Xcode and confirmed both layouts display unobstructed blue-on-black fluid; drag/release, swirl/fade, brief tap dye and one-finger double-tap pause/resume behaved as expected. See [02-PARITY.md](./02-PARITY.md) for individual rows and provenance.
- The two-finger shortcut was **not tested**. Independent simultaneous touches, lift/cancel, and proportional stroke comparison were not observed; physical device and macOS 26 runtime remain untested. Mac mouse/Space/S behavior uses the previously observed macOS 27 `01-BASELINE.md` reference, not a new runtime claim.

## Deviations from Plan
- None; Xcode's GUI first requested an installation step and the user re-opened the project before observing results.

## Issues Encountered
- Simulator.app could not be located at the old Xcode developer-app path. The user opened the project in Xcode and ran the iOS scheme there on both simulator devices.

## Next Phase Readiness
- Phase-level verification can check the build and evidence against PLAT-02, PLAT-03, and SIM-01. Unobserved two-finger and physical multi-touch cases are visible as verification debt, not passes.

## Self-Check: PASSED
- Both builds, both fresh simulator installations/launches and the recorded user-observed checks are supported by the results table; unperformed cases remain labelled NOT TESTED.

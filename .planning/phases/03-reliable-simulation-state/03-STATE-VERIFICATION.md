---
phase: 03-reliable-simulation-state
status: awaiting-human-observation
updated: 2026-09-25
---

# Phase 3 — Simulation State Verification

**Date / host:** 2026-09-25; Apple Silicon Mac macOS 27.0 (26A428); Xcode 27.0 (27A266a). iPhone 17 Pro iOS 26.4 simulator `8393A81F-69D4-439E-AF8E-ED7665022800`; iPad Pro 13-inch (M5) iOS 26.4 simulator `98C63B09-8AB0-4B26-B9C4-5277D60FCBD5`.

## Automated evidence

| Check | Result | Reproduce / evidence |
|-------|--------|----------------------|
| Four-field cycle, running→paused→switch→resumed, running and user-paused inactivity return | PASS | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` — 4 XCTest methods executed, 0 failed; production `Shared/SimulationState.swift` compiled in test target. |
| Tuning force/dye/radius/swirl/retention/iterations defaults, low/high bounds, non-finite fallback for floating properties, mutation/reset retaining field/pause | PASS | Same XCTest suite, `testTuningDefaultsBoundsAndNonFinite` and `testResetOnlyChangesTuning`. Defaults 1, 0.8, 150, 0.4, 0.998, 40. |
| Mac no-override Debug build | PASS | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` — BUILD SUCCEEDED. |
| iOS no-override Debug build | PASS | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build` — BUILD SUCCEEDED. |
| Offscreen previous-phase contacts and Phase 3 field resampling | PASS | `python3 -m unittest -v test_phase02_metal test_phase03_metal` — 2 tests OK, using freshly built Mac `default.metallib` from build settings. Source 64×32 RG16F → destination 32×96; seeded corner + center RG tuples (0.5,0.25), (1,0.5), (1.5,0.75), (2,1), (3,1.5) matched density/pressure within 0.06; velocity checked x×0.5/y×3 at same five locations. |
| Fresh simulator installs and process launch | PASS | `xcodebuild ... -showBuildSettings -json` resolved `.../Build/Products/Debug-iphonesimulator/FluidDynamicsMetaliOS.app`; `xcrun simctl install <UDID> <app>` and `xcrun simctl launch <UDID> ro.andreisergiupitis.FluidDynamicsMetaliOS` returned PID 46769 (phone) and 46789 (tablet). This proves launch, not visual rendering. |

## Live interaction — human checkpoint

Mark a row PASS only after direct observation on the named host; provide reproduction details for failures. A build or offscreen shader result does not verify an on-screen interaction.

| Behavior | Mac macOS 27 | iPhone 17 Pro iOS 26.4 | iPad Pro M5 iOS 26.4 | Observation / steps |
|----------|--------------|-----------------------|-------------------------|---------------------|
| Density visible, retained and fitted across wide/narrow live resize or rotation | NOT TESTED | NOT TESTED | NOT TESTED | Stir, resize window or rotate simulator, compare the same blue pattern and edges. |
| Pressure/velocity/vorticity fields retained after resize | NOT TESTED | NOT TESTED | NOT TESTED | Change fields before and after resize; confirm no cleared field. |
| Drag held during resize and fresh stir afterward | NOT TESTED | NOT TESTED | NOT TESTED | Move while resizing, look for no large jump; start a new stroke. Held rotation may be simulator-inaccessible. |
| Pause, switch through four fields immediately without motion, resume selected field | NOT TESTED | NOT TESTED | NOT TESTED | Mac Space/S; iOS one-finger/two-finger double taps where reproducible. Physical two-finger gesture remains device-only. |
| Paused resize retains frozen, fitted image; held drag resumes without stale impulse | NOT TESTED | NOT TESTED | NOT TESTED | Pause, resize, inspect stationary fluid; resume while holding pointer/touch. |
| Running background/return retains image, field and fresh touch | N/A | NOT TESTED | NOT TESTED | iOS Home then return, stir again. |
| User-paused background/return remains paused and retains field/image | N/A | NOT TESTED | NOT TESTED | User pause then Home/return; resume manually and stir. |
| Interrupted touch/tap clears on inactivity | N/A | NOT TESTED | NOT TESTED | Start contact, leave app, return; confirm no force or dye replay. |

**Separately deferred:** Actual macOS 26 runtime launch/drag is NOT TESTED (`01-HUMAN-UAT.md`); physical two-finger and concurrent-touch behavior is NOT TESTED (`02-HUMAN-UAT.md`). Neither is inferred from these simulators.

---
phase: 02-modern-ios-parity
plan: 02
subsystem: ios-input
tags: [multitouch, metal, gestures, fluid]
requires:
  - phase: 02-modern-ios-parity
    provides: iOS 26 runnable simulator app from plan 01
provides:
  - Stable independent live touch snapshots and bounded GPU contact batches
  - Delayed stationary tap dye with responsive drag and canvas-relative iOS radius
affects: [02-03, phase-03]
tech-stack:
  added: []
  patterns: [Contact identity retained by controller, Swift and Metal ten-slot uniform layout]
key-files:
  created: []
  modified: [FluidDynamicsMetaliOS/RenderViewController.swift, Shared/Renderer.swift, Shared/Shaders.metal]
key-decisions:
  - "Batch contacts beyond ten into extra force passes rather than dropping them."
  - "Keep stationary touch pending until the hold interval or single-tap recognition; move above three points starts immediately."
patterns-established:
  - "The controller sends a complete live snapshot; each GPU buffer clears absent contacts explicitly."
requirements-completed: [PLAT-02, PLAT-03, SIM-01]
duration: 4 min
completed: 2026-09-24
---

# Phase 02 Plan 02: Independent iOS touch and gesture input summary

**Stable per-finger tracking sends ten-contact GPU batches, while iOS taps wait for shortcut resolution and iPad splats scale with canvas width.**

## Performance
- Started: 2026-09-24T20:50:00Z
- Completed: 2026-09-24T20:54:30Z
- Tasks: 2/2
- Files modified: 3

## Task Commits
- Task 1: `f9468cd` — stable touch identities, bounded GPU force passes, matching ten-slot Swift/Metal layout, empty snapshot clearing.
- Task 2: `53835c3` — pending stationary touches, drag threshold, single/double recognizer precedence, one-shot tap queue and iOS-only squared radius.

## Verification
- `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build` — exit 0 after each source task.
- `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` — exit 0 after each shared-source task.
- Freshly rebuilt iOS app was reinstalled on iPhone 17 Pro iOS 26.4 simulator; `xcrun simctl launch` returned PID 43229, exit 0.
- Controller no longer copies a changed-touch `Set` through `malloc`/`memcpy`; ended/cancelled touches remove only their identities. Swift `StaticData` and Metal `BufferData` both contain ten `float2` positions followed by ten impulses (80 + 80 bytes), then scalar (8), offsets (8), screen size (8), radius (4). Extra touches use separate buffers and force passes. Empty snapshots explicitly zero positions, impulses and scalar impulse. Mac keeps its original `updateInteraction(points:in:)` and `150 / ScreenScaleAdjustment` radius; scalar blue `(0, 0.06, 0.19)`, fade `0.998h`, curl `(0.4, 0.4)`, and 40 pressure iterations remain in source.
- Single- and two-finger double taps retain existing actions; the single-tap recognizer waits for both to fail before enqueuing dye. Stationary holds trigger after 0.35 seconds and movements of at least three points forward promptly. This is code-backed only; no direct gesture, drag or physical multi-touch observation has been performed. Plan 03 contains the manual checkpoint.

## Deviations from Plan
- No scope changes. The iOS launch was repeated after source changes to check that the newly built app still starts.

## Issues Encountered
- Xcode reports existing `float2` deprecation warnings; both schemes build. This phase does not migrate the shared solver types.

## Next Phase Readiness
- Plan 03 must collect iPhone/iPad visual and gesture observations. Simulator launch alone does not demonstrate touch behavior or physical-device multi-touch.

## Self-Check: PASSED
- Both target builds exited 0 after each task; the iOS simulator launch exited 0. Human visual verification is outstanding in Plan 03.

---
phase: 03-reliable-simulation-state
plan: 01
subsystem: simulation
tags: [MetalKit, XCTest, lifecycle, pause]
requires: []
provides: [shared bounded state, executable Mac XCTest suite, pause-only rendering, lifecycle-aware input]
affects: [03-02, 03-03]
tech-stack:
  added: [XCTest target]
  patterns: [separate user pause from inactivity, render-only paused draw]
key-files:
  created: [Shared/SimulationState.swift, FluidDynamicsMetalStateTests/SimulationStateTests.swift, FluidDynamicsMetal.xcodeproj/xcshareddata/xcschemes/FluidDynamicsMetalOSX.xcscheme]
  modified: [Shared/Renderer.swift, FluidDynamicsMetaliOS/RenderViewController.swift, FluidDynamicsMetalOSX/RenderViewController.swift, FluidDynamicsMetal.xcodeproj/project.pbxproj]
key-decisions:
  - "Store future tuning in a bounded Foundation-only value type; leave current GPU constants intact."
requirements-completed: [SIM-03, VER-01]
duration: 12 min
completed: 2026-09-25
---

# Phase 03 Plan 01: Shared State and Paused Rendering Summary

**Four-field selection, bounded resettable tuning, user/lifecycle pause separation and render-only paused frames with four executable XCTest cases.**

## Performance
- **Tasks:** 2
- **Files modified/created:** 7

## Task Commits
1. State, tests and Xcode target: `7b84538`
2. Paused rendering, shortcuts and lifecycle input clearing: `150e940`

## Verification
- `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`: 4 XCTest methods executed; 0 failures.
- `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build`: passed.
- Existing shader defaults, four field order, and Space/S + iOS double-tap selectors retained. Live pause/gesture observation is reserved for Plan 03.

## Deviations from Plan
None - plan executed as specified.

## Issues Encountered
None. Existing `float2` deprecation warnings remain in builds.

## Self-Check: PASSED
- Production state is compiled into both apps and the Mac XCTest target; all four state tests run and pass.
- Paused `draw(in:)` only renders the selected texture; contacts are cleared before resuming.

## Next Phase Readiness
Ready for 03-02 texture migration and resize input rebasing.

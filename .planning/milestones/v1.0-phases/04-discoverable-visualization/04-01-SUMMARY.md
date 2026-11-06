---
phase: 04-discoverable-visualization
plan: 01
subsystem: ui
tags: [AppKit, MetalKit, XCTest, HUD]
requires:
  - phase: 03-reliable-simulation-state
    provides: Paused presentation and shared simulation state
provides:
  - Direct named field selection in shared state and renderer
  - Always-visible macOS field and pause controls
affects: [04-02, 04-03]
tech-stack:
  added: []
  patterns: [Renderer state drives control presentation, native HUD above root MTKView]
key-files:
  created: []
  modified: [Shared/SimulationState.swift, Shared/Renderer.swift, FluidDynamicsMetalStateTests/SimulationStateTests.swift, FluidDynamicsMetalOSX/RenderViewController.swift]
key-decisions:
  - Keep the full-size Metal canvas and place AppKit controls in a compact overlay.
  - Use the existing paused renderer presentation branch for direct selection.
patterns-established:
  - Refresh field and pause labels from renderer.state after button or shortcut actions.
requirements-completed: [CTRL-01]
duration: 5min
completed: 2026-09-25
---

# Phase 4 Plan 01: Mac named field controls

**Direct field selection with paused redraw and a native Mac HUD on the full-size fluid canvas.**

## Performance
- **Duration:** 5 min
- **Completed:** 2026-09-25T09:12:42Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments
- Added direct selection preserving user pause and inactivity, with a six-test Mac XCTest run including the new selection test.
- Added an upper-trailing Mac field grid and Pause/Resume button with renderer-backed selection, accessibility values, focused-Space filtering and a Reduce Transparency opaque surface.
- Mac Debug build succeeded. Live layout, focus and hit-testing observations remain for Plan 03.

## Task Commits
1. **Task 1: Direct selection and Mac HUD** — `baa3614`
2. **Task 2: Guard HUD-origin canvas dragging** — `fe4a587`

## Deviations from Plan
None - plan executed with the approved controller-local HUD approach.

## Issues Encountered
An unavailable `NSFont.smallSystemFont` factory stopped the first build; replaced it with `NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)` and reran the suite successfully.

## Next Phase Readiness
Ready for 04-02 iOS HUD. Actual Mac behavior and accessibility layouts require the Plan 03 checkpoint.

## Self-Check: PASSED
- `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`: 6 tests, 0 failures.
- `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build`: exit 0.

---
phase: 08-spatial-inspection
plan: "04"
subsystem: macOS UI
tags: [swift, appkit, macOS, spatial-inspection, gestures, accessibility]
requires:
  - phase: 08-spatial-inspection
    provides: Validated inspection state, camera APIs, and depth-equipped spatial presentation
provides:
  - Native plane, depth, camera, Centre Slice, and Reset Camera controls
  - A noninteractive, hit-transparent X/Y/Z orientation guide that follows camera rotation
  - Exclusive paused canvas orbit/zoom and focus-safe panel/canvas keyboard routing
affects: [08-05, 08-06, 08-09, spatial-inspection]
tech-stack:
  added: []
  patterns:
    - Inspection controls render committed renderer state without a layout rebuild per simulation step
    - Canvas gestures are accepted only from the canvas window; panel events retain native panel ownership
key-files:
  created:
    - Sources/macOS/OrientationGuide3DView.swift
  modified:
    - Sources/macOS/RenderViewController.swift
    - Sources/macOS/InspectionSlider3D.swift
    - Tests/UI/macOS/HUDUITests.swift
    - FluidDynamicsMetal.xcodeproj/project.pbxproj
key-decisions:
  - "Keep the separate Simulation Controls panel out of canvas keyboard/gesture tests; reopen it before reading panel-owned control state."
  - "Update the stale lesson-copy assertion to the current slice wording rather than changing the runtime copy."
  - "Treat appearance screenshots as retained evidence only; do not infer human visual or accessibility acceptance."
patterns-established:
  - "Focused native controls handle their own Space/arrows; a panel-originated Space never falls through to canvas transport."
  - "Canvas drag ownership is cleared on mode transition, deactivation, minimization, and close; scroll direction is normalized once."
requirements-completed: []
duration: approximately 2h
completed: 2026-11-14
---

# Phase 8 Plan 04: Native Spatial Controls and Gestures Summary

**Native slice/camera controls and a rotation-following orientation guide now support keyboard operation and isolated paused canvas gestures without changing the established 2D solver or ABI.**

## Performance

- **Duration:** Approximately 2 hours.
- **Started:** 2026-11-14T09:22:48Z (first Task 1 RED commit; exact session-start time not captured).
- **Completed:** 2026-11-14T11:23:50Z.
- **Tasks:** 2/2.
- **Files modified:** 5 plan files.

## Accomplishments

- Added native plane, shared-depth, orbit, elevation, and zoom controls, plus depth-only Centre Slice and camera-only Reset Camera actions. Slider keyboard increments remain focused-control behavior and values refresh from committed renderer state.
- Added `OrientationGuide3DView` as a subdued, hit-transparent, non-focusable X/Y/Z guide with one accessibility element. Its axes follow camera rotation, and its stroke/label contrast follows the system Increase Contrast setting.
- Routed paused primary drag and vertical scroll from the canvas to camera orbit/zoom only. Canvas ownership is cleared at lifecycle boundaries; panel-originated drag, scroll, and Space remain isolated from camera and transport.
- Updated focused UI regressions for the current lesson copy, the panel-first-responder Space case, canvas-focused `S`/Space behavior, and Light/Dark/contrast capture naming.

## Task Commits

1. **Task 1: Add native plane, depth and keyboard camera controls** — RED `fbd1c2a`; implementation `d63aae1`.
2. **Task 2: Add the axis guide and exclusively owned canvas gestures** — RED `b4897a1`; implementation `8724f8f`.

## Files Created/Modified

- `Sources/macOS/RenderViewController.swift` — inspection UI refresh, orientation-guide placement/accessibility, lifecycle cleanup, canvas gesture and keyboard routing.
- `Sources/macOS/InspectionSlider3D.swift` — native continuous slider keyboard increments (Task 1).
- `Sources/macOS/OrientationGuide3DView.swift` — camera-aligned, hit-transparent X/Y/Z guide.
- `Tests/UI/macOS/HUDUITests.swift` — spatial focus/gesture regressions and named appearance captures.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj` — Mac-only orientation-guide source membership.

## Decisions Made

- AppKit can leave the separate controls panel as first responder after mode selection. The event monitor now leaves panel-originated keys with that panel rather than dispatching Space to canvas transport; a dedicated regression covers this case.
- Canvas-focused input checks close the controls panel before interacting with the canvas, then reopen it before reading counters or sliders. Space may advance the counter while the panel is reopening, so assertions check committed transport state rather than assuming the counter is unchanged.
- The failing lesson-copy assertion was stale; it was updated to match the current runtime slice wording. No runtime-copy change was needed for that failure.

## Deviations from Plan

None in production scope. The UI test setup was tightened to explicitly separate panel and canvas event ownership, as required by the plan and UI contract.

## Issues Encountered

- The first focused rerun reproduced the outdated “cross-section / fixed plane” assertion. After correcting it, the test exposed that canvas Space was attempted while the separate controls panel could still own focus. The test now hides the panel for canvas `S`/Space input and reopens it before reading panel-owned values; `testThreeDPanelFocusAndReturn` then passed.
- The Repowise change-risk service had no repository index and could not analyze the changed files. A scoped inline source review was performed instead; this is not independent-agent verification.

## User Setup Required

None.

## Verification

- Focused `HUDUITests.testThreeDPanelFocusAndReturn`: **1/1 passed**. Result bundle: `/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Logs/Test/Test-FluidDynamicsMetalOSX-2026.11.14_11-00-37-+0000.xcresult`.
- Full macOS state/HUD suite: **25 state tests + 19 HUD tests passed, 0 failures**. Result bundle: `/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Logs/Test/Test-FluidDynamicsMetalOSX-2026.11.14_11-01-18-+0000.xcresult`.
- macOS and iOS Simulator Debug builds with no overrides: **passed**. The iOS build emitted the existing `UIRequiresFullScreen` deprecation warning.
- Production fixtures `test_spatial_slices` and `test_inspection_routing`: **2/2 passed**. Evidence: `.build/fluid3d-evidence/spatial-slices.json`, `.build/fluid3d-evidence/inspection-routing.json`; the spatial fixture also retained `cube-increase-contrast.ppm`.
- Light/Dark Standard Contrast appearance capture passed and is retained in `/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Logs/Test/Test-FluidDynamicsMetalOSX-2026.11.14_11-12-02-+0000.xcresult`.
- Light/Dark Increase Contrast appearance capture passed and is retained in `/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Logs/Test/Test-FluidDynamicsMetalOSX-2026.11.14_11-11-24-+0000.xcresult`. The temporary system contrast preference was restored to its original unset state.
- `git diff --check` passed before planning closeout; it is rerun after this summary/state update.

Screenshots are evidence only, not human visual acceptance. VoiceOver review and physical mouse/trackpad direction/feel checks remain **NOT TESTED**. Actual macOS 26 runtime behavior also remains **NOT TESTED** on this macOS 27 host.

## Next Plan Readiness

- 08-04 / Wave 4 is complete; 08-05 / Wave 5 is next but was **not started**.
- Plans 08-05–08-09 and phase-level verification were not run.
- Phase 8 requirements INS-01, INS-02, INS-03, INS-04, and CTRL-08 remain pending until their complete acceptance scope, including the later human checkpoint, is satisfied.

---
*Phase: 08-spatial-inspection*
*Completed: 2026-11-14*

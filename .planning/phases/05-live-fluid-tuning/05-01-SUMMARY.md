---
phase: 05-live-fluid-tuning
plan: 01
subsystem: simulation-ui
tags: [metal, appkit, tuning, gpu-tests]
requires:
  - phase: 04-discoverable-visualization
    provides: Native Mac field and pause HUD
provides:
  - Shared four-control slider mapping with exact original Fade detent
  - Running-frame force, dye, swirl and retention wiring through matched Metal uniforms
  - Collapsible Mac tuning HUD and shader readback regression
affects: [05-02, 05-03, 06-quality-reset-accessibility]
tech-stack:
  added: []
  patterns: [one state snapshot per running frame, one bounded HUD scroll area]
key-files:
  created: [test_phase05_metal.py, test_phase05_metal.swift]
  modified: [Shared/SimulationState.swift, Shared/Renderer.swift, Shared/Shaders.metal, FluidDynamicsMetalOSX/RenderViewController.swift, FluidDynamicsMetalStateTests/SimulationStateTests.swift, FluidDynamicsMetalOSXUITests/HUDUITests.swift]
key-decisions:
  - "Use the approved piecewise Fade mapping with an exact 0.998 default detent."
  - "Write uniforms only when acquiring the next running-frame buffer; keep paused slabs frozen."
requirements-completed: [CTRL-02, CTRL-03, CTRL-04]
duration: 10 min
completed: 2026-09-25
---

# Phase 05 Plan 01: Shared and Mac live tuning

**Native Mac sliders feed bounded shared state into real contact and shader passes, with exact original constants at their default positions.**

## Performance
- **Tasks:** 2/2
- **Files changed:** 8

## Accomplishments
- Force, Dye and Swirl map to twice the slider position; Fade maps 0/17/100% to 0.9995/0.998/0.9905 retention without quantizing the stored value.
- Renderer snapshots tuning once per running frame, including additional contact batches. Both velocity and density advect with the same retention; confinement consumes the current swirl.
- Mac HUD starts closed and exposes the four controls with live percentages and a bounded single scroll region. Tuning values remain across disclosure and pause.

## Task Commits
1. **Task 1: Shared mapping and Metal wiring** — `bc10715`
2. **Task 2: Mac HUD and GPU readback** — `015a062`

## Verification
- Mac scheme `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`: 8 state tests and 5 Mac UI tests passed (2026-09-25).
- `python3 -m unittest test_phase05_metal.py`: 1 offscreen GPU test passed; default vector/scalar splats, independent zeros, both retention paths and nonuniform vorticity readback.
- iOS Simulator generic scheme build returned 0 after shared Swift/Metal changes.
- Live visual default parity and 320×240 scroll behavior await Plan 03 human observations.

## Deviations from Plan
- The Mac HUD uses one bounded scroll region for all controls at compact sizes; at roomy sizes all field and pause controls remain visible. No nested scroll view is active.

## Issues Encountered
- macOS XCTest's normalized slider adjustment produced an accessibility API error; coordinate clicking exercised the native slider successfully.
- Pre-existing uncommitted focused-Space edits in the Mac controller and its UI test were kept in the working tree and excluded from both task commits.

## Self-Check: PASSED
- Source/test/harness files exist and both task commits are present; automated checks above exited 0.

## Next Phase Readiness
- Shared tuning API and four production GPU paths are ready for the iOS HUD in 05-02. Human appearance and compact layout observations remain in 05-03.

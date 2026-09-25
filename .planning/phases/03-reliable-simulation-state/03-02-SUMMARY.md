---
phase: 03-reliable-simulation-state
plan: 02
subsystem: simulation
tags: [Metal, RG16F, resize, input]
requires: [03-01]
provides: [five-field GPU migration, offscreen resize readback, pointer and touch rebasing]
affects: [03-03]
tech-stack:
  added: [offscreen Metal resize unittest]
  patterns: [drain in-flight frames before GPU state migration]
key-files:
  created: [test_phase03_metal.swift, test_phase03_metal.py]
  modified: [Shared/Renderer.swift, Shared/Shaders.metal, FluidDynamicsMetaliOS/RenderViewController.swift, FluidDynamicsMetalOSX/RenderViewController.swift]
key-decisions:
  - "Resample old ping into new ping at normalized coordinates; scale velocity components by axis grid ratios."
requirements-completed: [SIM-02, SIM-03]
duration: 12 min
completed: 2026-09-25
---

# Phase 03 Plan 02: GPU Resize Migration Summary

**Five RG16F fields resampled across large aspect changes while retaining field/pause state and rebasing held input.**

## Performance
- **Tasks:** 2
- **Files modified/created:** 6

## Task Commits
1. Five-field resampling and offscreen readback: `72cf63b`
2. Mac mouse and iOS touch rebasing: `3686ab4`

## Verification
- Mac no-override Debug build: passed.
- iOS iPhone 17 Pro iOS 26.4 no-override Debug build: passed.
- Mac `xcodebuild test`: four methods executed, zero failures.
- `python3 -m unittest -v test_phase02_metal test_phase03_metal`: 2 tests passed.
- GPU readback: 64×32 → 32×96; four corners and center retain seeded density/pressure RG values within 0.06. Velocity x/y components scale by 0.5/3 at the same locations. Texture input probes use small marker patches to account for nearest-neighbor sampling on downscale.
- Renderer takes three in-flight permits before migrating old ping textures into five replacement ping textures and releases them before paused redraw. An unsuccessful GPU completion leaves the old fields intact. Zero/unchanged dimensions skip migration.

## Deviations from Plan
None - plan executed as specified.

## Issues Encountered
- Initial one-pixel marker at the left boundary missed the downsampled pixel center; seeded a 3×3 marker to test retained regions rather than a sampling-phase coincidence.

## Self-Check: PASSED
- All declared files present, task commits recorded, builds and automated checks pass.
- Live Mac resize and iOS rotation/held input still require Plan 03 human observation.

## Next Phase Readiness
Ready for 03-03 build/test evidence and UI checkpoint.

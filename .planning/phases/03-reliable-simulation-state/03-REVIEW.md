---
phase: 03-reliable-simulation-state
status: issues_found
depth: standard
files_reviewed: 9
critical: 0
warning: 1
info: 1
total: 2
reviewed: 2026-09-25
---

# Phase 03 Code Review

Reviewed `Shared/SimulationState.swift`, `Shared/Renderer.swift`, `Shared/Shaders.metal`, both `RenderViewController.swift` files, `FluidDynamicsMetalStateTests/SimulationStateTests.swift`, `test_phase03_metal.swift`, `test_phase03_metal.py`, and Xcode test target/scheme integration. Both app builds, four XCTest methods and two offscreen Metal tests passed. This is an inline review because the typed `gsd-code-reviewer` is unavailable in this runtime.

## Findings

### WR-01 — Renderer publishes replacements even if the resample pipeline cannot encode

`Shared/Renderer.swift` lines 443–457 checks that the command buffer completes, but `RenderShader.calculateWithCommandBuffer` silently does nothing when pipeline creation fails (`Shared/RenderShader.swift` lines 54–73, 85–97). An empty command buffer can report `.completed`, so a shader/pipeline setup failure would replace all five fields with uninitialized textures. Expose pipeline readiness or return an encoder-success result and keep the old slabs unless all five passes were encoded and completed. Current successful builds and offscreen shader readback do not exercise pipeline-creation failure.

### IN-01 — Deprecated SIMD alias warnings

`float2` in `Shared/Renderer.swift` and both controller files is deprecated in the current toolchain. The warning predates this phase and does not change the layout or test outcome; a later focused migration can use `SIMD2<Float>` with buffer-layout verification.

## Disposition

Advisory code review. No security issues found. Live resize and pause/lifecycle interactions were approved by the user on the available hosts. Physical-device two-finger gestures remain NOT TESTED.

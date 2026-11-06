# Feature Research

**Date:** 2026-09-24

## Table stakes for this modernization

| Capability | Evidence and complexity | Dependency |
|------------|-------------------------|------------|
| Fluid canvas remains interactive on both platforms | Existing `Shared/Renderer.swift` and both `RenderViewController.swift` files; medium migration risk | Both apps build |
| Pause/resume and field selection are visible in app UI | Current gestures/keys are documented only in `README.md`; low-medium | App state bridge |
| Direct manipulation remains responsive during tuning | `MTKView` timed drawing supported by [Apple docs](https://developer.apple.com/documentation/metalkit/mtkview.md); medium | Renderer settings API |
| Parameter controls show valid ranges and reset defaults | Values currently hard-coded in `Shared/Renderer.swift` / `Shared/Shaders.metal`; medium | Explicit configuration model |
| Accessible, native controls for keyboard/pointer/touch | Different platform input paths already exist; medium | UI redesign |

## Differentiators deferred unless requested

- Preset library, file export, and saved sessions could extend the playground but do not serve the requested first milestone; no persistence implementation exists today.
- Solver changes or new effects are deliberately deferred to keep existing fluid behavior recognizable.

## Anti-features

- Intel Mac and pre-macOS 26 compatibility: excluded explicitly.
- Pre-iOS 26 support: excluded by user decision.
- A broad simulation-rewrite phase before an app runs: unnecessary migration risk.

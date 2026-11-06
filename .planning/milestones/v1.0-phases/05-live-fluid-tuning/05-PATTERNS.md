# Phase 5 — Existing Integration Patterns

**Mapped:** 2026-09-25

| Role | Existing source | Phase 5 reuse |
|------|-----------------|---------------|
| Bounds, defaults, reset | `Shared/SimulationState.swift`, `FluidDynamicsMetalStateTests/SimulationStateTests.swift` | Put the pure, shared slider-position mapping beside `SimulationTuning` so both apps and the existing production-state test target compile it; retain force 1, dye 0.8, swirl 0.4, retention 0.998 and the wider safety bounds. |
| Input snapshot | `Shared/Renderer.swift` (`draw(in:)`, `writeContacts`, `nextBuffer`) | Read `state.tuning` on each running frame, scale only vector impulses by force, and use dye independently for scalar impulses. Cover the extra batches of more than ten contacts; do not modify slabs on a slider change. |
| Solver uniforms | `Shared/Renderer.swift` (`StaticData`, three in-flight buffers), `Shared/Shaders.metal` (`BufferData`, `advect`, `vorticityConfinement`) | Extend both matching layouts with a 16-byte vector carrying retention and swirl; set it only on a free running-frame buffer. Preserve existing shader entry points, radius and 40 pressure passes. |
| Mac overlay | `FluidDynamicsMetalOSX/RenderViewController.swift`, `FluidDynamicsMetalOSXUITests/HUDUITests.swift` | Extend the upper-trailing `NSVisualEffectView`, native field/pause actions and focused-Space monitor; keep actual HUD bounds as the input exclusion. Existing HUD UI tests locate controls by accessibility name. |
| iOS overlay | `FluidDynamicsMetaliOS/RenderViewController.swift`, `FluidDynamicsMetaliOSUITests/HUDUITests.swift` | Extend the lower-trailing safe-area `UIVisualEffectView` and `isHUDTouch`, preserving raw-touch and recognizer filtering, the outside single tap and double-tap shortcuts. Avoid nested scrolling in compact layout. |
| GPU behavior regression | `test_phase03_metal.py`, `test_phase03_metal.swift` | Create a focused Phase 5 offscreen harness against the freshly built Mac `default.metallib`; use RG16F inputs and readback to distinguish real shader results at defaults, zeros and changed swirl/retention. |

**Binding contracts:** `05-CONTEXT.md` D-01–D-10, `05-UI-SPEC.md` (exact percentage/Fade detent and compact HUD rules), `05-VALIDATION.md`, and the Phase 4 HUD/shortcut checks. The existing UI-SPEC is approved and the draft validation strategy already exists; neither needs regeneration during planning.

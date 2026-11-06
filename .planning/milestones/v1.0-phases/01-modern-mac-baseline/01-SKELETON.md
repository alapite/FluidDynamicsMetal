# Walking Skeleton — FluidDynamicsMetal Modernization

**Phase:** 1
**Generated:** 2026-09-24

## Capability Proven End-to-End

A user opens the macOS app on Apple Silicon, drags the mouse over the Metal canvas, and sees familiar animated density respond.

## Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | Existing AppKit storyboard + `MTKView` + shared Metal renderer | Working user-input-to-GPU pipeline already exists; preserve its behavior. |
| Platform | Mac target minimum macOS 26; arm64 build | Phase 1 establishes the supported Apple Silicon baseline. |
| Language | Modern supported Swift language mode on Mac target (start with Swift 5) | Enable current Xcode compilation while minimizing source churn; iOS target follows in Phase 2. |
| State/data | In-memory GPU `Slab` textures and `StaticData`/`BufferData` uniforms; no database | The app is a local interactive simulation; no server, API or persisted data is involved. |
| Entry/interaction | `Main.storyboard` → `RenderViewController` → `Renderer` → `Shaders.metal` | Real pointer input travels through the full existing pipeline. |
| Delivery | Locally built macOS `.app`, verified with a Metal-enabled desktop session | No backend or hosted deployment exists; a runnable Mac build is the full-stack slice. |

## Stack Touched in Phase 1

- [x] Mac scheme builds without deployment-target override using a supported Xcode + Metal Toolchain.
- [x] Existing storyboard-backed app launches and creates an on-screen window; visual Metal canvas content awaits manual confirmation.
- [ ] Real mouse drag writes an impulse consumed by the GPU and updates displayed density.
- [x] Local run command and code-backed visual/default-behavior reference are recorded in `01-BASELINE.md`.

## Out of Scope (Deferred to Later Slices)

- Phase 2: iOS target migration and cross-platform Swift compatibility.
- Phase 3: resize/pause robustness and automated state tests.
- Phases 4–6: native controls, live tuning, quality/reset, and accessibility.
- Database, network routing, and hosted deployment: not part of this native offline app.

## Subsequent Slice Plan

- Phase 2: reproduce working fluid interaction on iOS and modernize both schemes.
- Phase 3: preserve interaction through lifecycle/state changes with automated coverage.
- Phases 4–6: add discoverable views and parameter controls, then verify usability.

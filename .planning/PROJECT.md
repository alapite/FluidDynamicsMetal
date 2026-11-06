# FluidDynamicsMetal

## What This Is

Interactive educational Metal fluid simulation for Mac, iPhone, and iPad, built with Swift 6 language mode and Swift 6.2+ tooling. Users can explore Free Play and three deterministic 2D lessons through named fields, tracers, trails, tuning, and step-by-step playback. The next milestone adds a Mac-first true-3D teaching foundation; actual macOS 26 runtime and physical-device multitouch remain unverified follow-ups.

## Core Value

People can interact with a responsive, visually familiar fluid simulation on both supported platforms and adjust it without editing source code.

## Requirements

### Validated

- ✓ Three deterministic 256-square lessons demonstrate advection, interacting vortices, and dye stretching, with adjustments, restart, single-step, and 600-step completion — post-v1.0 educational release, commit `07703e2`; documented evidence in `docs/educational-release-verification.md` (2026-10-13).
- ✓ Named field palettes, velocity arrows, passive particles/trails, separate dye fading and motion damping, and native lesson controls are delivered on Mac/iPhone/iPad — educational release evidence; physical-device checks remain explicitly NOT TESTED.
- ✓ Shared production GPU evolution supports offscreen numerical, restart-repeatability, lesson-observation, and performance checks — educational release evidence on Apple M3 Pro; measurements are not mobile-device benchmarks.
- ✓ Both app targets render an interactive Metal fluid simulation — existing code in `Shared/Renderer.swift` and both `RenderViewController.swift` files.
- ✓ Users can pause and switch between density, pressure, velocity, and vorticity views — existing controllers and `Shared/Renderer.swift`.
- ✓ Shared pause/field transitions and bounded tuning defaults/reset have a runnable production-state XCTest suite — validated in Phase 3: Reliable simulation state.
- ✓ Fluid survives Mac live resize and iOS simulator rotation/view resize; observed pause/resume and return remain responsive — validated on available hosts in Phase 3.
- ✓ Mac, iPhone and iPad users can directly choose a named displayed field and Pause/Resume from a compact native HUD over the interactive canvas — user-approved core flow and shared-state XCTest in Phase 4.
- ✓ Both apps offer live Force, Dye, Swirl and Fade controls in their existing HUD, retaining the original solver defaults — validated in Phase 5 through state/HUD tests, numeric Metal readback and user-approved Mac/iPhone/iPad observations.
- ✓ Developers can follow separate no-override Mac, iPhone and iPad build and manual interaction checklists for the existing apps — validated in Phase 6: Platform compatibility closeout, on the available macOS 27 host and iOS 26.4 simulators. Actual macOS 26 runtime remains a separate Phase 1 follow-up.
- ✓ The simulation retained its familiar blue-on-black character during modernization — user-approved Mac/iPhone/iPad available-host interaction and numeric Metal checks in v1.0; actual macOS 26 runtime remains untested.

### Active

- [ ] Explore a genuine 64³ three-dimensional fluid simulation on Mac alongside the existing 2D experience.
- [ ] Compare initial speeds in one deterministic 3D dye-advection lesson using Run/Pause, Step, and Restart.
- [ ] Inspect the fluid using an orbit camera, movable cross-sections, and passive tracers.
- [ ] View the dye as a basic transparent volume after establishing slice/tracer inspection.
- [ ] Validate numerical behaviour, repeatability, presentation independence, and GPU performance before expanding resolution or platform scope.

### Out of Scope

- Intel Mac compatibility and macOS releases earlier than 26 — explicitly excluded by the compatibility baseline.
- iOS releases earlier than 26 — user chose the latest iOS baseline.
- Changes to the existing 2D solver's behaviour — it remains the established reference experience; the 3D solver is an additional path.
- 3D interacting-vortex and dye-stretching lessons, mobile 3D delivery, and freehand 3D injection — deferred beyond the focused foundation milestone.
- Free-surface water, obstacles, calibrated physical units, and scientific-grade accuracy — retain qualitative educational scope.
- User-selectable 3D resolutions and advanced cinematic rendering — benchmark the 64³ baseline before expanding quality controls.

## Context

- The codebase has two storyboard-backed app targets and shared Swift/Metal sources compiled into both; see `.planning/codebase/ARCHITECTURE.md` and `.planning/codebase/STACK.md`.
- Both targets now use Swift 6 language mode with Swift 6.2+ / Xcode 26+ tooling and deployment minimums of macOS 26 / iOS 26. App/shared sources live under `Sources/{macOS,iOS,Shared}`. Mac state tests, Mac/iOS HUD tests, and integration GPU harnesses are present; there is no Swift package.
- The post-v1.0 educational release was delivered outside the archived GSD phases. Its implementation and verification documents under `docs/` describe the current baseline; historical v1.0 records retain their original outcomes.
- The simulation runs a series of fragment-shader passes each frame, including 40 pressure iterations. Swift shader names and uniform-buffer layouts must continue to match their Metal counterparts.
- `FluidSimulation` owns GPU evolution independently of the view; `FieldVisualization` and `ParticleSystem` handle presentation and tracers. The existing solver uses 2D RG16F ping/pong textures and fragment passes; the proposed 3D path uses compute kernels and volumetric fields.
- The 2026-10-13 educational release report records 1.11–1.54 ms mean GPU cost for 256-square lessons on an M3 Pro, depending on overlays. This is historical 2D evidence, not a forecast for 3D performance.

## Constraints

- **Compatibility:** macOS 26 on Apple Silicon and iOS 26 on current iPhone/iPad hardware — no legacy-platform work.
- **Product behavior:** Preserve the fluid's recognizable look and feel while modernizing app internals and controls.
- **Architecture:** Shared simulation code must work in both app targets; Swift/Metal function names and buffer layouts are cross-language contracts.
- **Milestone platform:** Deliver the new 3D mode on Apple Silicon Mac first while retaining both existing app builds and 2D behaviour.
- **Numerics:** Use a fixed 64³ starting grid, deterministic lesson setup, step-based progression, and qualitative explanations. Choose pressure-solve settings using numerical evidence rather than inheriting 40 iterations without validation.
- **Performance:** Measured 30 fps floor at 64³ and 1280×720 output on a named available Apple Silicon reference Mac for both slices/tracers and volume/tracers; 60 fps is an optimization goal, not a milestone gate.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Modernize both macOS and iOS apps | Both existing apps remain part of the product | Phase 2 both-scheme Debug builds and iPhone/iPad simulator interactions verified; Mac macOS 26 runtime deferred. |
| Use macOS 26 / Apple Silicon and iOS 26 baselines | Prioritize current-platform APIs over backward compatibility | Both targets build without deployment overrides using Swift 5. |
| Redesign the UI around native controls and parameter tuning | Make the simulation approachable without source edits | Phase 4 named field selection and pause controls and Phase 5 live tuning approved on Mac/iPhone/iPad. |
| Preserve solver behavior during modernization | Maintain the existing experience as a reference point | User-approved original-looking defaults on available Mac/iPhone/iPad hosts in v1.0; macOS 26 runtime NOT TESTED. |
| Preserve fields across canvas changes and separate manual pause from lifecycle inactivity | Avoid reset, catch-up, or stale-input impulses | Phase 3 Mac and iOS simulator checks passed; two-finger gestures still need a physical device. |
| Treat Xcode 27 Device Hub multitouch limits as verification debt, not a release gate | Two-finger taps/pans cannot be reproduced through the former Option-key simulator mechanism; developers cannot fix the tooling | User confirmed on 2026-09-25 that NOT TESTED physical-device cases do not block later phases or milestone completion; [forum discussion](https://developer.apple.com/forums/thread/846533). |
| Defer new Phase 6 controls and further accessibility work | Finish current-platform compatibility this milestone without adding features | CTRL-05/06/07 move to v2; Phase 6 covers VER-02 and preserves the existing HUD and interactions. |
| Close v1.0 with macOS 26 runtime deferred | Prioritize other work rather than hold the milestone for an unavailable runtime host | User decision on 2026-09-25; archive PLAT-01 as NOT TESTED, keep Phase 1 UAT open for later. |
| Deliver v1.1 as a Mac-first 3D teaching foundation | Validate real 3D dynamics, inspection, and performance before expanding lesson/platform scope | User approved 2026-11-06; implementation pending. |
| Start with one 64³ dye-advection lesson and slices/tracers before volume rendering | Establish a testable, inspectable vertical slice early | User approved 2026-11-06; implementation pending. |
| Keep inspection focused on dye slices, camera, passive tracers, and a selectable volume view | Make depth understandable within a bounded foundation milestone | User approved 2026-11-06; other fields and trails deferred. |
| Reuse the existing 600-step lesson contract | Keep comparison and transport behaviour familiar | User approved 2026-11-06; three initial speeds, restart-on-adjustment, paused entry/restart. |
| Require 30 fps at 64³ / 1280×720 on a named reference Mac | Establish a measured usable baseline before pursuing higher quality | User approved 2026-11-06; measurements pending. |

## Current State

v1.0 is archived with 14/14 implementation plans complete and 11/12 v1 requirements verified. The subsequent educational release (`07703e2`) added the current lesson engine and Swift 6 baseline; its 2026-10-13 report records passing Mac and iOS simulator builds, Mac state/HUD tests, iPhone/iPad HUD tests, and GPU integration checks. These are recorded prior results, not checks rerun during milestone initialization. Actual macOS 26 runtime and physical-device multitouch remain NOT TESTED. See `.planning/MILESTONES.md` for historical v1.0 outcomes and `docs/educational-release-verification.md` for the newer baseline.

## Current Milestone: v1.1 3D Teaching Foundation

**Goal:** Let learners explore a genuine three-dimensional dye-advection experiment on Mac, with clear views into the fluid and measured numerical/performance behaviour.

**Target features:**
- True 3D fluid evolution on a fixed 64³ grid.
- One deterministic dye-advection lesson with speed comparisons and Run/Pause, Step, and Restart.
- Orbit camera, movable cross-sections, and passive tracers.
- Basic transparent dye-volume rendering after the slice/tracer foundation.
- GPU correctness, repeatability, presentation-independence, and performance evidence.

The user approved 23 requirements in `.planning/REQUIREMENTS.md` and the four-phase roadmap (phases 7–10) on 2026-11-06. Phase 7 is ready for discussion and planning. Deferred macOS 26 runtime and device-only multitouch checks remain tracked follow-ups rather than newly asserted compatibility claims.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:** review requirements for validation or removal, capture new requirements and decisions, and check that What This Is remains accurate.

**After each milestone:** reassess the core value, scope boundaries, and current technical context.

---
*Last updated: 2026-11-06 after v1.1 milestone scope approval and current-codebase reconciliation*

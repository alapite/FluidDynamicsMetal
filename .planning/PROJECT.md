# FluidDynamicsMetal Modernization

## What This Is

Modernize the existing interactive Metal fluid simulation for macOS 26 on Apple Silicon and iOS 26 on current iPhone/iPad hardware. Keep its recognizable fluid behavior while replacing aging project and app code with maintainable, current-platform implementations and adding native, discoverable controls for field selection and simulation tuning on both platforms.

## Core Value

People can interact with a responsive, visually familiar fluid simulation on both supported platforms and adjust it without editing source code.

## Requirements

### Validated

- ✓ Both app targets render an interactive Metal fluid simulation — existing code in `Shared/Renderer.swift` and both `RenderViewController.swift` files.
- ✓ Users can pause and switch between density, pressure, velocity, and vorticity views — existing controllers and `Shared/Renderer.swift`.

### Active

- [ ] Both app targets build and run using current Xcode/Swift for macOS 26 (Apple Silicon only) and iOS 26.
- [ ] Preserve the existing fluid simulation's characteristic appearance and interaction while modernizing the implementation.
- [ ] Provide platform-native, discoverable controls for pausing, selecting the displayed field, and tuning meaningful simulation parameters without changing code.
- [ ] Establish repeatable verification for the shared simulation and both app targets.

### Out of Scope

- Intel Mac compatibility and macOS releases earlier than 26 — explicitly excluded by the compatibility baseline.
- iOS releases earlier than 26 — user chose the latest iOS baseline.
- Intentional solver redesign or changes to the fluid's character — preserve current behavior during modernization.

## Context

- The codebase has two storyboard-backed app targets and shared Swift/Metal sources compiled into both; see `.planning/codebase/ARCHITECTURE.md` and `.planning/codebase/STACK.md`.
- Both targets now use Swift 5 and deployment minimums of macOS 26 / iOS 26; no automated test target or settings UI exists yet. Values remain hard-coded in `Shared/Renderer.swift` and `Shared/Shaders.metal`.
- The simulation runs a series of fragment-shader passes each frame, including 40 pressure iterations. Swift shader names and uniform-buffer layouts must continue to match their Metal counterparts.
- Native UI direction: keep the fluid canvas central while exposing understandable, platform-appropriate parameter and display controls. Exact layout, parameters, and verification strategy will be specified during planning.

## Constraints

- **Compatibility:** macOS 26 on Apple Silicon and iOS 26 on current iPhone/iPad hardware — no legacy-platform work.
- **Product behavior:** Preserve the fluid's recognizable look and feel while modernizing app internals and controls.
- **Architecture:** Shared simulation code must work in both app targets; Swift/Metal function names and buffer layouts are cross-language contracts.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Modernize both macOS and iOS apps | Both existing apps remain part of the product | Phase 2 both-scheme Debug builds and iPhone/iPad simulator interactions verified; Mac macOS 26 runtime deferred. |
| Use macOS 26 / Apple Silicon and iOS 26 baselines | Prioritize current-platform APIs over backward compatibility | Both targets build without deployment overrides using Swift 5. |
| Redesign the UI around native controls and parameter tuning | Make the simulation approachable without source edits | — Pending |
| Preserve solver behavior during modernization | Maintain the existing experience as a reference point | — Pending |

## Current State

Phase 2 complete: the iOS 26 simulator app launches on iPhone/iPad and the user observed familiar blue fluid and drag/tap interaction; the Mac scheme still builds. `02-HUMAN-UAT.md` retains untested two-finger, concurrent-contact, and proportional-stroke checks. Phase 1 macOS 26 runtime remains deferred to milestone closeout. Phase 3 will address reliable lifecycle, resize and shared-state checks.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:** review requirements for validation or removal, capture new requirements and decisions, and check that What This Is remains accurate.

**After each milestone:** reassess the core value, scope boundaries, and current technical context.

---
*Last updated: 2026-09-24 after Phase 2*

# FluidDynamicsMetal Modernization

## What This Is

Modernize the existing interactive Metal fluid simulation for macOS 26 on Apple Silicon and iOS 26 on current iPhone/iPad hardware. Keep its recognizable fluid behavior while replacing aging project and app code with maintainable, current-platform implementations and adding native, discoverable controls for field selection and simulation tuning on both platforms.

## Core Value

People can interact with a responsive, visually familiar fluid simulation on both supported platforms and adjust it without editing source code.

## Requirements

### Validated

- ✓ Both app targets render an interactive Metal fluid simulation — existing code in `Shared/Renderer.swift` and both `RenderViewController.swift` files.
- ✓ Users can pause and switch between density, pressure, velocity, and vorticity views — existing controllers and `Shared/Renderer.swift`.
- ✓ Shared pause/field transitions and bounded tuning defaults/reset have a runnable production-state XCTest suite — validated in Phase 3: Reliable simulation state.
- ✓ Fluid survives Mac live resize and iOS simulator rotation/view resize; observed pause/resume and return remain responsive — validated on available hosts in Phase 3.
- ✓ Mac, iPhone and iPad users can directly choose a named displayed field and Pause/Resume from a compact native HUD over the interactive canvas — user-approved core flow and shared-state XCTest in Phase 4.

### Active

- [ ] Both app targets build and run using current Xcode/Swift for macOS 26 (Apple Silicon only) and iOS 26.
- [ ] Preserve the existing fluid simulation's characteristic appearance and interaction while modernizing the implementation.
- [ ] Provide platform-native, discoverable controls for pausing, selecting the displayed field, and tuning meaningful simulation parameters without changing code.
- [ ] Complete repeatable verification for the final native controls on available hosts; retain device-only multitouch observations as non-blocking follow-ups.

### Out of Scope

- Intel Mac compatibility and macOS releases earlier than 26 — explicitly excluded by the compatibility baseline.
- iOS releases earlier than 26 — user chose the latest iOS baseline.
- Intentional solver redesign or changes to the fluid's character — preserve current behavior during modernization.

## Context

- The codebase has two storyboard-backed app targets and shared Swift/Metal sources compiled into both; see `.planning/codebase/ARCHITECTURE.md` and `.planning/codebase/STACK.md`.
- Both targets use Swift 5 and deployment minimums of macOS 26 / iOS 26; a Mac XCTest state target and an offscreen Metal regression harness now run. Native field/pause HUDs are present on both platforms; live tuning is not yet available. Solver values remain hard-coded in `Shared/Renderer.swift` and `Shared/Shaders.metal`.
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
| Redesign the UI around native controls and parameter tuning | Make the simulation approachable without source edits | Phase 4 named field selection and pause controls approved on Mac/iPhone/iPad; parameter tuning remains Phase 5 work. |
| Preserve solver behavior during modernization | Maintain the existing experience as a reference point | — Pending |
| Preserve fields across canvas changes and separate manual pause from lifecycle inactivity | Avoid reset, catch-up, or stale-input impulses | Phase 3 Mac and iOS simulator checks passed; two-finger gestures still need a physical device. |
| Treat Xcode 27 Device Hub multitouch limits as verification debt, not a release gate | Two-finger taps/pans cannot be reproduced through the former Option-key simulator mechanism; developers cannot fix the tooling | User confirmed on 2026-09-25 that NOT TESTED physical-device cases do not block later phases or milestone completion; [forum discussion](https://developer.apple.com/forums/thread/846533). |

## Current State

Phase 4 complete on available hosts: native field and pause HUDs on Mac/iPhone/iPad passed user approval; six production-state XCTest methods and both Debug app builds passed, as did five prior-phase regression checks. Mac large-text/appearance and some device-layout variants were not individually reported; `04-REVIEW.md` tracks an advisory Mac large-text layout warning. Device Hub two-finger and physical concurrent-touch cases remain NOT TESTED and explicitly non-blocking for Phase 5/6 and milestone completion. Phase 1 macOS 26 runtime remains a separate deferred milestone-closeout check. Phase 5 adds live fluid tuning.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:** review requirements for validation or removal, capture new requirements and decisions, and check that What This Is remains accurate.

**After each milestone:** reassess the core value, scope boundaries, and current technical context.

---
*Last updated: 2026-09-25 after Phase 4*

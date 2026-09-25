# FluidDynamicsMetal Modernization

## What This Is

Modernize the existing interactive Metal fluid simulation for macOS 26 on Apple Silicon and iOS/iPadOS 26 on current hardware. Keep its recognizable fluid behavior while replacing aging project and app code with maintainable, current-platform implementations. Native field-selection and simulation-tuning controls are already delivered; close out this milestone with repeatable compatibility verification rather than additional features.

## Core Value

People can interact with a responsive, visually familiar fluid simulation on both supported platforms and adjust it without editing source code.

## Requirements

### Validated

- ✓ Both app targets render an interactive Metal fluid simulation — existing code in `Shared/Renderer.swift` and both `RenderViewController.swift` files.
- ✓ Users can pause and switch between density, pressure, velocity, and vorticity views — existing controllers and `Shared/Renderer.swift`.
- ✓ Shared pause/field transitions and bounded tuning defaults/reset have a runnable production-state XCTest suite — validated in Phase 3: Reliable simulation state.
- ✓ Fluid survives Mac live resize and iOS simulator rotation/view resize; observed pause/resume and return remain responsive — validated on available hosts in Phase 3.
- ✓ Mac, iPhone and iPad users can directly choose a named displayed field and Pause/Resume from a compact native HUD over the interactive canvas — user-approved core flow and shared-state XCTest in Phase 4.
- ✓ Both apps offer live Force, Dye, Swirl and Fade controls in their existing HUD, retaining the original solver defaults — validated in Phase 5 through state/HUD tests, numeric Metal readback and user-approved Mac/iPhone/iPad observations.
- ✓ Developers can follow separate no-override Mac, iPhone and iPad build and manual interaction checklists for the existing apps — validated in Phase 6: Platform compatibility closeout, on the available macOS 27 host and iOS 26.4 simulators. Actual macOS 26 runtime remains a separate Phase 1 follow-up.

### Active

- [ ] Both app targets build and run using current Xcode/Swift for macOS 26 (Apple Silicon only) and iOS 26.
- [ ] Preserve the existing fluid simulation's characteristic appearance and interaction while modernizing the implementation.
- [ ] Close out the deferred macOS 26 runtime launch/drag check on an eligible host; retain device-only multitouch observations as non-blocking follow-ups.

### Out of Scope

- Intel Mac compatibility and macOS releases earlier than 26 — explicitly excluded by the compatibility baseline.
- iOS releases earlier than 26 — user chose the latest iOS baseline.
- Intentional solver redesign or changes to the fluid's character — preserve current behavior during modernization.
- New resolution/quality controls, an in-app reset action and further accessibility work in this milestone — deferred to a later milestone.

## Context

- The codebase has two storyboard-backed app targets and shared Swift/Metal sources compiled into both; see `.planning/codebase/ARCHITECTURE.md` and `.planning/codebase/STACK.md`.
- Both targets use Swift 5 and deployment minimums of macOS 26 / iOS 26; a Mac XCTest state target and offscreen Metal regression harness run. Native field/pause HUDs on both platforms now include bounded live Force/Dye/Swirl/Fade tuning backed by shared state and Metal uniforms. Radius, pressure iterations and simulation resolution retain their original constants; quality and visible reset controls are deferred.
- The simulation runs a series of fragment-shader passes each frame, including 40 pressure iterations. Swift shader names and uniform-buffer layouts must continue to match their Metal counterparts.
- Native UI direction: retain the existing compact, platform-appropriate HUD and central interactive fluid canvas. Phase 6 documents and verifies the delivered controls without expanding them.

## Constraints

- **Compatibility:** macOS 26 on Apple Silicon and iOS 26 on current iPhone/iPad hardware — no legacy-platform work.
- **Product behavior:** Preserve the fluid's recognizable look and feel while modernizing app internals and controls.
- **Architecture:** Shared simulation code must work in both app targets; Swift/Metal function names and buffer layouts are cross-language contracts.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Modernize both macOS and iOS apps | Both existing apps remain part of the product | Phase 2 both-scheme Debug builds and iPhone/iPad simulator interactions verified; Mac macOS 26 runtime deferred. |
| Use macOS 26 / Apple Silicon and iOS 26 baselines | Prioritize current-platform APIs over backward compatibility | Both targets build without deployment overrides using Swift 5. |
| Redesign the UI around native controls and parameter tuning | Make the simulation approachable without source edits | Phase 4 named field selection and pause controls and Phase 5 live tuning approved on Mac/iPhone/iPad. |
| Preserve solver behavior during modernization | Maintain the existing experience as a reference point | — Pending |
| Preserve fields across canvas changes and separate manual pause from lifecycle inactivity | Avoid reset, catch-up, or stale-input impulses | Phase 3 Mac and iOS simulator checks passed; two-finger gestures still need a physical device. |
| Treat Xcode 27 Device Hub multitouch limits as verification debt, not a release gate | Two-finger taps/pans cannot be reproduced through the former Option-key simulator mechanism; developers cannot fix the tooling | User confirmed on 2026-09-25 that NOT TESTED physical-device cases do not block later phases or milestone completion; [forum discussion](https://developer.apple.com/forums/thread/846533). |
| Defer new Phase 6 controls and further accessibility work | Finish current-platform compatibility this milestone without adding features | CTRL-05/06/07 move to v2; Phase 6 covers VER-02 and preserves the existing HUD and interactions. |

## Current State

Phase 6 complete for VER-02 on available hosts: both no-override builds, Mac state/HUD and GPU tests, separate process launches and a user-approved manual walkthrough for Mac, iPhone and iPad are documented in `06-COMPATIBILITY-VERIFICATION.md`. The Phase 6 iPhone and iPad UI-test runs timed out without a usable result and remain NOT TESTED for this run. Physical multitouch remains NOT TESTED and non-blocking; Phase 1 actual macOS 26 runtime launch/drag is still pending at milestone closeout. New quality, reset and accessibility work belongs to a later milestone.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:** review requirements for validation or removal, capture new requirements and decisions, and check that What This Is remains accurate.

**After each milestone:** reassess the core value, scope boundaries, and current technical context.

---
*Last updated: 2026-09-25 after Phase 6 completion*

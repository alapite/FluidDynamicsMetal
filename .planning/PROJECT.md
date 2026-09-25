# FluidDynamicsMetal Modernization

## What This Is

Interactive Metal fluid simulation with Swift 5 Mac and iOS/iPadOS builds, native field-selection and pause controls, and live fluid tuning. v1.0 closed on the available macOS 27 / iOS 26.4 hosts; actual macOS 26 runtime launch/drag remains an unverified follow-up rather than a shipped compatibility claim.

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
- ✓ The simulation retained its familiar blue-on-black character during modernization — user-approved Mac/iPhone/iPad available-host interaction and numeric Metal checks in v1.0; actual macOS 26 runtime remains untested.

### Active

- [ ] Verify the Mac app runs on an actual Apple Silicon macOS 26 host; builds and macOS 27 interaction are validated, but the macOS 26 runtime remains NOT TESTED and deferred beyond v1.0.
- [ ] When prioritised, revisit the deferred macOS 26 runtime launch/drag and physical-device multitouch checks. Neither blocks v1.0 closure.

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
| Preserve solver behavior during modernization | Maintain the existing experience as a reference point | User-approved original-looking defaults on available Mac/iPhone/iPad hosts in v1.0; macOS 26 runtime NOT TESTED. |
| Preserve fields across canvas changes and separate manual pause from lifecycle inactivity | Avoid reset, catch-up, or stale-input impulses | Phase 3 Mac and iOS simulator checks passed; two-finger gestures still need a physical device. |
| Treat Xcode 27 Device Hub multitouch limits as verification debt, not a release gate | Two-finger taps/pans cannot be reproduced through the former Option-key simulator mechanism; developers cannot fix the tooling | User confirmed on 2026-09-25 that NOT TESTED physical-device cases do not block later phases or milestone completion; [forum discussion](https://developer.apple.com/forums/thread/846533). |
| Defer new Phase 6 controls and further accessibility work | Finish current-platform compatibility this milestone without adding features | CTRL-05/06/07 move to v2; Phase 6 covers VER-02 and preserves the existing HUD and interactions. |
| Close v1.0 with macOS 26 runtime deferred | Prioritize other work rather than hold the milestone for an unavailable runtime host | User decision on 2026-09-25; archive PLAT-01 as NOT TESTED, keep Phase 1 UAT open for later. |

## Current State

v1.0 is archived with 14/14 implementation plans complete and 11/12 v1 requirements verified. Both no-override builds, Mac state/HUD and GPU tests, separate process launches and a user-approved manual walkthrough for Mac, iPhone and iPad are documented in `06-COMPATIBILITY-VERIFICATION.md`. Phase 6 iPhone/iPad UI automation timed out without usable results. PLAT-01 actual macOS 26 runtime remains NOT TESTED and explicitly deferred beyond v1.0; physical multitouch is also NOT TESTED and non-blocking. See `.planning/MILESTONES.md` for the shipped scope and archive.

## Next Milestone Goals

To be chosen when higher-priority work is defined. Unscheduled follow-ups include the deferred PLAT-01 runtime check, quality/resolution, visible reset and further accessibility work; none is asserted as an immediate next task.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:** review requirements for validation or removal, capture new requirements and decisions, and check that What This Is remains accurate.

**After each milestone:** reassess the core value, scope boundaries, and current technical context.

---
*Last updated: 2026-09-25 after v1.0 milestone closure*

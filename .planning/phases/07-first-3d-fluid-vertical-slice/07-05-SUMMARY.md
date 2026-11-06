---
phase: 07-first-3d-fluid-vertical-slice
plan: 05
subsystem: simulation-state, mobile-ui
tags: [swift, xctest, xctest-ui, ios, playback]

# Dependency graph
requires: []
provides:
  - Explicit 3D dye-advection mode identity and lesson capabilities in shared simulation state
  - Paused 3D entry/reset, bounded logical lesson-step queuing, and guarded 2D-only state actions
  - Explicit iOS 2D-only mode selection while retaining existing lesson navigation
affects: [07-06, 07-07, simulation-state, mobile-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Explicit platform mode catalogs separate mobile 2D availability from Mac mode availability
    - Lesson transport uses explicit lesson identity rather than treating a missing 2D experiment as Free Play

key-files:
  created: []
  modified:
    - Sources/Shared/SimulationState.swift
    - Tests/Unit/SimulationStateTests.swift
    - Sources/iOS/RenderViewController.swift
    - Tests/UI/iOS/HUDUITests.swift

key-decisions:
  - "Keep SimulationMode.allCases as the legacy 2D compatibility list so the existing positional Mac selector does not expose unfinished 3D UI."
  - "Expose dyeAdvection3D separately through macModes and use twoDimensionalModes explicitly in the iOS selector."
  - "Treat 3D as a lesson for paused transport and the existing step bound, while keeping 2D field/overlay/adjustment actions inert in 3D."

patterns-established:
  - "Use SimulationMode.is3D and isLesson for mode capabilities; do not infer Free Play from experiment == nil."
  - "Keep platform availability explicit at each native selector boundary."

requirements-completed: [SIM-04, SIM-06, LES-01, LES-02, LES-06]

# Metrics
duration: 21min
completed: 2026-11-06
---

# Phase 7 Plan 05: Explicit 3D State and Mobile 2D Continuity Summary

**Shared state now distinguishes the paused 3D dye-advection lesson from Free Play, and iOS continues to enumerate only its four established 2D modes.**

## Performance

- **Duration:** 21 min
- **Started:** 2026-11-06T21:59:59Z
- **Completed:** 2026-11-06T22:21:17Z
- **Tasks:** 2 completed
- **Files modified:** 4

## Accomplishments

- Added the `dyeAdvection3D` mode with the exact title `3D Dye Advection`, `is3D` / `isLesson` capabilities, and separate `twoDimensionalModes` / `macModes` catalogs. `experiment` remains `nil` for 3D rather than fabricating a 2D lesson identity.
- Made 3D mode selection and reset enter paused at step 0, cleared queued steps on reset/inactivity, bounded queued advances as a lesson, and prevented unsupported field, overlay, tuning-reset, and adjustment actions from changing 3D state. Free Play preferences and existing 2D lesson defaults remain intact.
- Added supplemental direct coverage that same-mode 3D re-selection and restart both clear queued work and reset the paused lesson transport to step 0.
- Switched the iOS experiment menu to `twoDimensionalModes` and added a HUD regression covering the four existing titles, 3D absence, lesson selection, a single paused step, and return to Free Play.
- Kept the existing Mac selector's compatibility list 2D-only; no unfinished 3D GPU path was exposed through its positional selection behavior.

## Task Commits

1. **Task 1 RED: 3D state transport tests** — `2e2b228` (`test(07-05): add failing tests for 3D state transport`)
2. **Task 1 GREEN: explicit 3D state behavior** — `5baadb5` (`feat(07-05): implement explicit 3D mode state`)
3. **Task 2: iOS 2D-only menu regression** — `5183db1` (`test(07-05): cover iOS 2D-only experiment navigation`)
4. **Task 2: explicit iOS mode list** — `43c2379` (`fix(07-05): use explicit 2D modes on iOS`)
5. **Supplemental: 3D reselect/restart reset regression** — `da13c02` (`test(07-05): cover 3D reselect and restart reset`)

**Initial plan metadata commit:** `f11a503` (`docs(07-05): complete 3D state transport and mobile 2D continuity plan`); this summary was updated afterward to record the supplemental regression and final verification.

## Files Created/Modified

- `Sources/Shared/SimulationState.swift` — 3D mode identity/capabilities, platform catalogs, bounded lesson transport, no-op guards, and preference-safe transitions.
- `Tests/Unit/SimulationStateTests.swift` — 3D entry/step, same-mode re-selection/restart reset, inactivity/manual intent, no-op actions, and 2D preference/default regression coverage.
- `Sources/iOS/RenderViewController.swift` — explicit 2D-only source for the mobile experiment menu.
- `Tests/UI/iOS/HUDUITests.swift` — menu availability and existing 2D lesson navigation/transport coverage.

## Verification

- **Task 1 RED:** the focused Mac state-test build failed at the expected missing API symbols (`dyeAdvection3D`, `is3D`, `isLesson`) before implementation; XCTest assertions could not run in that compile-failure state.
- **Task 1 GREEN:** focused Mac state suite passed — **24 tests, 0 failures**, including all four added 3D state tests and existing 2D defaults/field-cycle/600-step tests.
- **Supplemental review regression:** `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO -only-testing:FluidDynamicsMetalStateTests` — **25 tests, 0 failures** (18 simulation-state and 7 renderer-contact tests); `testThreeDReselectAndRestartResetPausedTransport` passed.
- `git diff --check` — passed for the supplemental regression.
- `xcrun swiftc -swift-version 6 -typecheck Sources/Shared/SimulationState.swift Sources/Shared/ExperimentRecipes.swift` — passed.
- `testExperimentMenuRemainsTwoDOnly` — passed on an iPhone 17 Pro simulator (iOS 26.4) and an iPad Pro 13-inch M5 simulator (iOS 26.4). Both runs verified all four 2D choices, absence of the 3D title/heading, lesson selection, Step 1, and return to Free Play.
- No-override Mac Debug build — passed.
- No-override iOS Simulator Debug build — passed. Xcode emitted the existing `UIRequiresFullScreen` deprecation warning; no build errors.
- `python3 -m unittest discover -s Tests/Integration` — **12 tests passed** in 58.061 seconds, including production renderer stepping/inactivity and GPU regressions on Apple M3 Pro.
- `python3 -m unittest Tests.Integration.test_phase02_settings` — **1 test passed**.
- Active Metal compiler check (`xcrun metal --version`) succeeded; no toolchain installation was needed.

### TDD Notes

- The Task 1 RED run demonstrated the missing production API through expected compiler errors; the full runtime assertions passed after the GREEN implementation.
- The Task 2 menu test was already green before the one-line selector change because `allCases` was intentionally still the legacy 2D-only compatibility list. The implementation makes that availability explicit through `twoDimensionalModes`; the same UI test passed again on both simulator form factors after the change.
- Inline review identified that the original state tests did not directly distinguish same-mode re-selection and lesson restart reset semantics; the supplemental regression now covers both and passed in the fresh 25-test run.

## Decisions Made

- `allCases` remains the established 2D compatibility list for current positional consumers. Future Mac selector work can use `macModes` with stable mode identity without prematurely shifting or exposing its existing entries.
- The shared state reuses lesson transport limits for 3D but does not claim full 3D completion/replay acceptance; those checks remain assigned to later plans.

## Deviations from Plan

None in scope or file ownership. The TDD observations above reflect that the new identity was initially absent and that mobile behavior was already correct under the permitted legacy 2D list.

## Issues Encountered

- The expected RED compile failure prevented runtime state assertions until the new mode API existed; implementation then passed the complete focused state suite.
- The supplemental state run emitted non-failing Xcode App Intents metadata and IDETestOperationsObserver/launch-session warnings; all 25 tests passed.
- Xcode and simulator emitted platform/tooling warnings (App Intents metadata skipped, upcoming `UIScene` lifecycle notice, and simulator accessibility duplicate-class notice). They did not cause test or build failures and were outside this plan's code scope.

## User Setup Required

None.

## Coverage Limits and Next Phase Readiness

- State and mobile availability contracts are ready for the renderer and Mac selector integration plans. This plan does **not** establish actual GPU 3D advancement, 3D numerical correctness, Mac 3D UI availability, or full 3D completion/replay behavior.
- UI verification used simulators only. Physical-device multitouch and actual macOS 26 runtime behavior remain **NOT TESTED**.
- `.planning/REQUIREMENTS.md` remains unchanged; the phase-level requirements stay pending until the remaining Phase 7 implementation plans complete end-to-end coverage.

## Threat Surface Scan

No new network, authentication, filesystem, or schema trust-boundary surface was introduced.

---
*Phase: 07-first-3d-fluid-vertical-slice*
*Completed: 2026-11-06*

## Self-Check: PASSED

- Summary file exists at the planned phase path.
- All four task implementation commits and the supplemental regression commit are present in the worktree history; the initial summary commit is `f11a503`.
- Summary records both simulator UI runs, both no-override builds, the original focused state run and fresh 25-test regression run, and integration regressions.
- `.planning/STATE.md` and `.planning/ROADMAP.md` were not modified.

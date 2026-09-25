---
phase: 4
slug: discoverable-visualization
status: verified-with-follow-ups
nyquist_compliant: false
wave_0_complete: true
created: 2026-09-25
---

# Phase 4 — Validation Strategy

> Per-phase feedback and observation contract for CTRL-01 and D-01–D-07.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Production-state XCTest plus macOS and iOS XCUITest targets; manual GPU/appearance and device-only HUD observation |
| **Config file** | `FluidDynamicsMetal.xcodeproj/project.pbxproj`, shared `FluidDynamicsMetalOSX.xcscheme` and `FluidDynamicsMetaliOS.xcscheme`, `FluidDynamicsMetalStateTests/SimulationStateTests.swift`, `FluidDynamicsMetalOSXUITests/HUDUITests.swift`, `FluidDynamicsMetaliOSUITests/HUDUITests.swift` |
| **Quick run command** | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` |
| **Full suite command** | Quick run; `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=8393A81F-69D4-439E-AF8E-ED7665022800' CODE_SIGNING_ALLOWED=NO` (substitute an available iPhone simulator ID); builds and manual observations in `04-HUD-VERIFICATION.md` |
| **Estimated runtime** | Cached Mac XCTest/XCUITest ~20–40 s; iPhone simulator XCUITest ~30–90 s; simulator startup and manual observations vary |

---

## Sampling Rate

- **After direct-selection state changes:** Run the Mac quick command (6 state cases and 2 Mac UI cases) and verify real test methods execute.
- **After each platform HUD integration:** Build the affected scheme; after shared renderer/controller edits, build both schemes.
- **After each plan wave:** Run the full automated commands applicable to that wave; observe on available hosts before claiming actual control/input behavior.
- **Before `/gsd-verify-work`:** Mac/iPhone UI checks green where available; separately record iPad UI runner, focused-Space and manual HUD appearance/input as verified, failing or NOT TESTED.
- **Max feedback latency:** One focused XCTest invocation or affected scheme build per implementation task, not a full simulator interaction loop after every edit.

---

## Per-Task Verification Map

| Task (plan / wave) | Requirement | Behavioral check | Automated command | Test file | Coverage |
|--------------------|-------------|------------------|-------------------|-----------|----------|
| 04-01 Task 1 / wave 1 | CTRL-01, D-05–D-06 | Out-of-order selection, pause and inactivity preservation; Mac named controls and paused selection | Mac quick run | `SimulationStateTests.swift`, `FluidDynamicsMetalOSXUITests/HUDUITests.swift` | COVERED for state/HUD feedback; paused GPU frame still manual |
| 04-01 Task 2 / wave 1 | CTRL-01, D-01–D-07 | Mac canvas Space/S sync, compact HUD, focused Space and off-HUD drag | Mac quick run; Mac build | `FluidDynamicsMetalOSXUITests/HUDUITests.swift` | PARTIAL: canvas shortcuts pass; focused field-button Space check failed during audit; layout/hit-testing need live check |
| 04-02 Task 1 / wave 2 | CTRL-01, D-05–D-07 | iOS direct selection, pause, canvas vs HUD double-tap | iPhone XCUITest from full suite; iOS build | `FluidDynamicsMetaliOSUITests/HUDUITests.swift` | PARTIAL: iPhone controls and gesture exclusion pass; dye/force and simultaneous fingers remain manual |
| 04-02 Task 2 / wave 2 | CTRL-01, D-01–D-04 | Safe-area, Dynamic Type, transparency and iPad layout | iOS build; iPad XCUITest when available | `FluidDynamicsMetaliOSUITests/HUDUITests.swift` | PARTIAL: iOS build passes; iPad UI run timed out; visual variants need observation |
| 04-03 Task 1 / wave 3 | CTRL-01 | Collect builds, executed tests and per-platform evidence | Mac and iOS commands above | `04-HUD-VERIFICATION.md` | COVERED for original 6 state tests and both builds; new UI results below |
| 04-03 Task 2 / wave 3 | CTRL-01, D-01–D-07 | Human live HUD and fluid input checkpoint | Manual host/device matrix | `04-HUD-VERIFICATION.md` | PARTIAL: previously approved core flow; unreported variants and audit follow-ups below |

*Coverage: COVERED = executable behavior verified; PARTIAL = behavior untested or unresolved; MISSING = no behavioral check.*

---

## Wave 0 Requirements

- [x] `FluidDynamicsMetalStateTests/SimulationStateTests.swift` already runs against production `Shared/SimulationState.swift` through the Mac shared scheme.
- [x] Direct-selection state test executes alongside five existing production-state tests (6/6 passed).
- [x] Two Mac UI tests and two iPhone simulator UI tests operate actual app controls (2/2 per platform passed on 2026-09-25).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Named fields, active indication, Pause/Resume, material/opaque fallback and compact layout | CTRL-01, D-01–D-05 | Build/unit test cannot prove legibility or actual rendered controls | Launch both apps; select Density, Pressure, Velocity, Vorticity in order and out of order; verify the active field indicator and label match, check reduced-transparency mode, resize Mac and rotate/resize iPhone/iPad. |
| Frozen field changes and old shortcut synchronization | CTRL-01, D-05, D-06 | State tests do not prove Metal draw or visual synchronization | Pause on each platform; choose another named field and see it immediately without fluid motion; exercise Mac Space/S and iOS one-/two-finger double taps where reproducible, then check selected button and Pause/Resume label. |
| Canvas interaction outside HUD, no accidental dye from HUD | CTRL-01, D-07 | Controller event routing and gesture recognizers require live observation | Drag/swipe immediately next to the group and elsewhere, then click/tap each HUD control (including repeated/double taps); the former stirs fluid and the latter changes only the selected field/pause state. Record physical iOS two-finger results separately if a simulator cannot reproduce them. |
| Mac focused field-button Space | CTRL-01, D-06 | The focused XCUITest scenario changed Pause to Resume after a field-button Space; validate native keyboard focus and distinguish a real shortcut collision from XCUITest event delivery before repairing the controller | Focus Vorticity using keyboard navigation, press Space once and inspect Pause/Resume; then focus the pause button and press Space once. Expected: selecting a field never pauses; pause button toggles exactly once. Audit reproduction: initial XCUITest clicked Vorticity then called `vorticity.typeKey(XCUIKeyboardKey.space, modifierFlags: [])`; `Pause simulation` was absent at `FluidDynamicsMetalOSXUITests/HUDUITests.swift:38` in the 11:04:37 Mac run. |
| iPad UI automation | CTRL-01, D-01–D-07 | iPad 26.4 simulator test command exceeded 600 s while simulator diagnostics were running; no result can be inferred | Retry the iOS XCUITest command with an available iPad simulator ID when its test runner is responsive; retain the earlier user-approved iPad core-flow observation separately. |

---

## Validation Sign-Off

- [x] Each executable task has a relevant automated build/test check or a preceding test dependency.
- [x] No three consecutive tasks without an automated verification step.
- [x] Existing state target is used for direct-selection assertions, not a duplicate state implementation.
- [x] No watch-mode commands.
- [x] Manual checks distinguish approved Mac and simulator core behavior from unreported settings variants and physical-device-only behavior.
- [ ] `nyquist_compliant` requires resolved focused-Space investigation and remaining automatable checks; passing builds/approval alone do not meet that bar.

**Automated evidence:** PASS on 2026-09-25; exact commands and separate live-observation statuses: `04-HUD-VERIFICATION.md`.

**Approval:** user approved Mac, iPhone and iPad core flow on 2026-09-25; per-check settings and physical multitouch not explicitly reported remain NOT TESTED in `04-HUD-VERIFICATION.md`.

## Validation Audit 2026-09-25

| Metric | Count |
|--------|-------|
| Gaps found | 3 (Mac UI controls, iOS UI controls, focused-Space/input boundary) |
| Resolved | 2 (Mac and iPhone simulator control/shortcut XCUITest paths) |
| Escalated | 1 (Mac focused-Space regression candidate; implementation changes outside validation scope) |

**Fresh commands:** Mac quick run: 6 state tests + 2 Mac UI tests, 0 failures. iPhone simulator full-suite command above: 2 UI tests, 0 failures. iPad simulator ID `98C63B09-8AB0-4B26-B9C4-5277D60FCBD5`: command timed out after 600 s with no result. Existing Phase 4 builds and historical human checkpoint are recorded in `04-HUD-VERIFICATION.md`; this audit does not overwrite their dated results.

**Coverage boundaries:** UI tests assert accessibility selection and pause state, Mac canvas shortcuts, and iOS canvas-vs-HUD double-tap routing. They do not measure GPU frame contents, fluid dye/force, physical simultaneous fingers, safe-area legibility or appearance settings. CTRL-01 is therefore PARTIAL for automated Nyquist verification until escalated behavior is resolved and remaining checks are verified where feasible.

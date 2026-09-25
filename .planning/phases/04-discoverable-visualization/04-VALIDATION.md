---
phase: 4
slug: discoverable-visualization
status: awaiting-human-verification
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
| **Framework** | Existing production-state XCTest target; Xcode builds for both apps; manual Mac and iPhone/iPad HUD observation |
| **Config file** | `FluidDynamicsMetal.xcodeproj/project.pbxproj`, `FluidDynamicsMetal.xcodeproj/xcshareddata/xcschemes/FluidDynamicsMetalOSX.xcscheme`, `FluidDynamicsMetalStateTests/SimulationStateTests.swift` |
| **Quick run command** | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` |
| **Full suite command** | Quick test; `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build`; `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`; manual UI checks |
| **Estimated runtime** | Cached automated checks ~1–4 minutes; manual Mac/iPhone/iPad checks depend on device availability |

---

## Sampling Rate

- **After direct-selection state changes:** Run the XCTest quick command and verify real test methods execute.
- **After each platform HUD integration:** Build the affected scheme; after shared renderer/controller edits, build both schemes.
- **After each plan wave:** Run the full automated commands applicable to that wave; observe on available hosts before claiming actual control/input behavior.
- **Before `/gsd-verify-work`:** All automated checks green, and manual HUD appearance/input checks recorded as observed or NOT TESTED separately.
- **Max feedback latency:** One focused XCTest invocation or affected scheme build per implementation task, not a full simulator interaction loop after every edit.

---

## Per-Task Verification Map

| Task area | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-----------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| Shared direct field selection and paused presentation | CTRL-01, D-05, D-06 | — | Active field and user pause remain consistent, no stale input replay | XCTest + Mac build | Quick run command | ✅ 6 production tests executed, including direct selection | ✅ automated; live pending |
| Mac floating controls and shortcut sync | CTRL-01, D-01–D-07 | — | HUD hit area does not steal canvas pointer events | Mac build + manual input/visual check | Mac build from full suite | ✅ Mac Debug build succeeds | ✅ automated; live pending |
| iOS floating controls and touch routing | CTRL-01, D-01–D-07 | — | HUD taps do not inject dye, outside touches still stir | iOS build + manual input/visual check | iOS build from full suite | ✅ iOS Simulator Debug build succeeds | ✅ automated; live pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `FluidDynamicsMetalStateTests/SimulationStateTests.swift` already runs against production `Shared/SimulationState.swift` through the Mac shared scheme.
- [x] Direct-selection state test executes alongside five existing production-state tests (6/6 passed).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Named fields, active indication, Pause/Resume, material/opaque fallback and compact layout | CTRL-01, D-01–D-05 | Build/unit test cannot prove legibility or actual rendered controls | Launch both apps; select Density, Pressure, Velocity, Vorticity in order and out of order; verify the active field indicator and label match, check reduced-transparency mode, resize Mac and rotate/resize iPhone/iPad. |
| Frozen field changes and old shortcut synchronization | CTRL-01, D-05, D-06 | State tests do not prove Metal draw or visual synchronization | Pause on each platform; choose another named field and see it immediately without fluid motion; exercise Mac Space/S and iOS one-/two-finger double taps where reproducible, then check selected button and Pause/Resume label. |
| Canvas interaction outside HUD, no accidental dye from HUD | CTRL-01, D-07 | Controller event routing and gesture recognizers require live observation | Drag/swipe immediately next to the group and elsewhere, then click/tap each HUD control (including repeated/double taps); the former stirs fluid and the latter changes only the selected field/pause state. Record physical iOS two-finger results separately if a simulator cannot reproduce them. |

---

## Validation Sign-Off

- [ ] Each executable task has a relevant automated build/test check or a preceding test dependency.
- [ ] No three consecutive tasks without an automated verification step.
- [ ] Existing state target is used for direct-selection assertions, not a duplicate state implementation.
- [ ] No watch-mode commands.
- [ ] Manual checks distinguish observed Mac, simulator, and physical-device-only behaviors.
- [ ] `nyquist_compliant` reflects actual evidence rather than build success alone.

**Automated evidence:** PASS on 2026-09-25; exact commands and separate live-observation statuses: `04-HUD-VERIFICATION.md`.

**Approval:** pending human HUD checkpoint; `nyquist_compliant: false` until real observations are recorded.

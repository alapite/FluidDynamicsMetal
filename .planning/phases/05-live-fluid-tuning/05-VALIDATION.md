---
phase: 5
slug: live-fluid-tuning
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-25
---

# Phase 5 — Validation Strategy

> Feedback and observation contract for CTRL-02, CTRL-03, CTRL-04 and decisions D-01–D-10. Final task IDs are assigned once plans exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Production-state XCTest, Mac and iOS XCUITest, existing offscreen Metal/Python unittest harness, and manual GPU/interaction observation |
| **Config file** | `FluidDynamicsMetal.xcodeproj/project.pbxproj`, `FluidDynamicsMetalStateTests/SimulationStateTests.swift`, both platform `HUDUITests.swift` files and `test_phase03_metal.py` / `test_phase03_metal.swift` (existing Metal harness example) |
| **Quick run command** | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` |
| **Full suite command** | Mac quick run; `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=<available-iPhone-id>' CODE_SIGNING_ALLOWED=NO`; run focused offscreen Metal tests against the freshly built Mac `default.metallib` |
| **Estimated runtime** | Cached Mac tests ~20–40 s; iPhone simulator UI tests ~30–90 s plus startup; Metal harness and manual observation vary |

---

## Sampling Rate

- **After shared mapping/uniform tasks:** Run the Mac quick command and focused offscreen GPU checks once implemented; ensure changed tests execute, not merely that a build succeeds.
- **After each platform HUD task:** Run affected scheme build and its focused HUD UI tests; after shared code or Metal edits, build both schemes.
- **After every plan wave:** Run the applicable full commands, including both targets once integrated.
- **Before `/gsd-verify-work`:** Automated checks green where available; observe force/dye independence, swirl/fade changes to running fluid, default visual similarity, short-window scrolling and canvas gestures in both apps. Record missing physical multi-touch coverage as NOT TESTED rather than a failed test.
- **Max feedback latency:** One focused scheme test/build or GPU harness per implementation task; simulator/manual observations at wave checkpoints.

---

## Per-Task Verification Map

| Planned behavior (assign task ID after planning) | Requirement | Test type | Automated command | File exists | Status |
|--------------------------------------------------|-------------|-----------|-------------------|-------------|--------|
| Slider mapping: four positions, endpoint bounds, default values, Fade direction/roundtrip | CTRL-02, CTRL-03, CTRL-04; D-08–D-10 | Shared XCTest | Mac quick run | New mapping tests in `SimulationStateTests.swift` | PASS — 8/8 state tests; 2 new |
| Force and Dye independence on real inputs including zero values, default impulses | CTRL-02; D-04–D-05 | Offscreen Metal behavior + Mac app interaction | Focused GPU harness after Mac Debug build; Mac quick run | `test_phase05_metal.py` and `.swift` | PASS numeric GPU splats and user-approved Mac/iPhone/iPad live checks |
| Swirl and shared velocity/density retention on existing nonempty fields without new contacts | CTRL-03, CTRL-04; D-06–D-07 | Offscreen Metal behavior + visual observation | Focused GPU harness after Mac Debug build | `test_phase05_metal.py` and `.swift` | PASS numeric GPU readback and user-approved Mac/iPhone/iPad live checks |
| Mac closed-by-default Tuning group, slider values, pause/field and keyboard/drag boundaries | CTRL-02–04; D-01–D-03, D-08 | Mac XCUITest + manual compact layout | Mac quick run | `FluidDynamicsMetalOSXUITests/HUDUITests.swift` | PASS 5/5 HUD UI tests; user approved 320×240 and interaction checks |
| iOS closed-by-default Tuning group, slider values, pause/field, touch/scroll boundaries | CTRL-02–04; D-01–D-03, D-08 | iPhone XCUITest + manual iPhone/iPad layout | iOS full-suite command with available simulator | `FluidDynamicsMetaliOSUITests/HUDUITests.swift` | PASS 6/6 iPhone HUD UI tests and user-approved iPhone/iPad observations; iPad automation timed out |

*Automated PASS is restricted to checks actually run; the Mac/iPhone/iPad live checks are separately attributed to the user's 2026-09-25 approval in `05-TUNING-VERIFICATION.md`. No threat-model-specific external exposure is expected: controls modify only local in-memory solver state.*

---

## Wave 0 Requirements

- [x] Production-state XCTest and Mac/iPhone HUD XCUITest targets already exist in the two shared schemes.
- [x] Existing offscreen Metal regression demonstrates how to run compiled shaders on `rg16Float` textures without changing the app.
- [x] Add mapping/default tests and actual force/dye/swirl/fade GPU behavior tests during the corresponding implementation tasks; no new test target required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Original-look default and the relative feel of Force, Dye, Swirl and Fade | CTRL-02–04 | Numeric state tests and isolated GPU pixels cannot establish recognizable motion and look | Launch each app; stir at defaults, compare to `01-BASELINE.md`/original GIF; adjust one slider at a time while running, watch ongoing fluid for Swirl/Fade and the next stroke movement for Force/Dye; restore defaults by relaunching. |
| Small Mac window and iPhone landscape/iPad expanded HUD, live slider drag, retained canvas input | CTRL-02–04; D-01–D-03 | Bounds, hit testing, scroll reachability and layout require actual on-screen interaction | Open Tuning, inspect/read all four percentages and drag every slider; resize/rotate, scroll inside the HUD, change the field/pause action and drag immediately outside the HUD. Verify closed initially and sticky-open after canvas drag. |
| Physical two-finger and concurrent iOS contact behavior | CTRL-02–04 | Xcode 27 Device Hub cannot reproduce the documented two-finger gestures | Test on physical iOS device when available; record NOT TESTED otherwise, as the user approved this follow-up as non-blocking. |

---

## Validation Sign-Off

- [x] Every finalized task has an automated check or explicit preceding Wave 0 dependency.
- [x] No three consecutive tasks without an automated verify step.
- [x] Newly needed behavior tests exist and have been run against production code/shaders.
- [x] Existing shared state, Mac UI, iOS UI and Metal test infrastructure can be extended without introducing a second simulation implementation.
- [x] No watch-mode commands.
- [x] `nyquist_compliant: true` after running numeric GPU/state/HUD checks and recording the user's live Mac/iPhone/iPad approval; physical multitouch and iPad UI automation remain NOT TESTED.

**Approval:** automated evidence and user-approved live-fluid/compact-layout observations recorded 2026-09-25 in `05-TUNING-VERIFICATION.md`; physical-device multitouch and iPad UI automation retain their separate NOT TESTED statuses.

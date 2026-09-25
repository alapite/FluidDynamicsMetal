---
phase: 5
slug: live-fluid-tuning
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-25
---

# Phase 5 — Validation Strategy

> Feedback and observation contract for CTRL-02, CTRL-03, CTRL-04 and decisions D-01–D-10. The dated audit trail distinguishes the initial gap from its renderer-level test remediation.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Production-state and Renderer contact-packing XCTest, Mac and iOS XCUITest, offscreen Metal/Python unittest harness, and manual interaction observation |
| **Config file** | `FluidDynamicsMetal.xcodeproj/project.pbxproj`, `FluidDynamicsMetalStateTests/SimulationStateTests.swift`, `FluidDynamicsMetalStateTests/RendererContactTests.swift`, both platform `HUDUITests.swift` files and `test_phase05_metal.py` / `test_phase05_metal.swift` |
| **Quick run command** | `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`; then `python3 -m unittest test_phase05_metal.py` against the fresh Mac `default.metallib` |
| **Full suite command** | Mac quick run; `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=<available-iPhone-id>' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO` (the default-parallel iPhone run timed out during this audit) |
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

| Task / wave | Requirement | Behavior and test file | Automated command | Status |
|-------------|-------------|------------------------|-------------------|--------|
| 05-01 Task 1 / wave 1 | CTRL-02–04; D-04–D-10 | Slider mapping/defaults in `SimulationStateTests.swift`; production `Renderer.writeContacts` Force/Dye independence, origin/empty sentinels and contact batching in `RendererContactTests.swift` | Mac quick run | **COVERED** — 8 mapping/state and 3 Renderer contact tests green |
| 05-01 Task 2 / wave 1 | CTRL-02–04; D-01–D-10 | Mac disclosure, values and field/canvas behavior in `FluidDynamicsMetalOSXUITests/HUDUITests.swift`; real force/dye splats and 0/17/100% Fade, 0/default/high Swirl in `test_phase05_metal.swift` via `test_phase05_metal.py` | Mac quick run + focused GPU harness | **COVERED** for HUD and shader effects; compact layout and held-stroke feel separately observed, not asserted by GPU test |
| 05-02 Task 1 / wave 2 | CTRL-02–04; D-01–D-10 | iOS closed disclosure and default sliders in `FluidDynamicsMetaliOSUITests/HUDUITests.swift`; state/Renderer/GPU tests exercise the shared path compiled by both apps | iPhone full-suite command + Mac/GPU commands | **COVERED** — iPhone UI passed previously; focused default case passed during remediation; shared contact/shader checks green |
| 05-02 Task 2 / wave 2 | CTRL-02–04; D-01–D-03, D-08 | iPhone Hide/Reopen, pause/field, inside/outside HUD double taps and landscape reachability in `FluidDynamicsMetaliOSUITests/HUDUITests.swift` | iPhone full-suite command | **COVERED** on iPhone; iPad automation NOT TESTED (timeout) and live iPad behavior user-approved separately |
| 05-03 Task 1 / wave 3 | CTRL-02–04; D-04–D-10 | Execute Mac state/UI, iPhone UI and production-shader readback; evidence in `05-TUNING-VERIFICATION.md` and this audit | Mac quick run + focused GPU harness + iPhone full-suite command | **COVERED** for commands executed; prior matrix records original numeric values |
| 05-03 Task 2 / wave 3 | CTRL-02–04; D-01–D-10 | Blocking user observation checkpoint, Mac/iPhone/iPad matrix in `05-TUNING-VERIFICATION.md` | None (manual checkpoint) | **MANUAL-ONLY** — user-approved live behavior, physical multitouch NOT TESTED |

*Automated PASS is restricted to checks actually run; the Mac/iPhone/iPad live checks are separately attributed to the user's 2026-09-25 approval in `05-TUNING-VERIFICATION.md`. The GPU harness supplies shader uniforms directly, while the new XCTest cases compile and exercise the actual shared Renderer contact packing and batch selection. No threat-model-specific external exposure is expected: controls modify only local in-memory solver state.*

---

## Wave 0 Requirements

- [x] Production-state XCTest and Mac/iPhone HUD XCUITest targets already exist in the two shared schemes.
- [x] Existing offscreen Metal regression demonstrates how to run compiled shaders on `rg16Float` textures without changing the app.
- [x] Add mapping/default and force/dye/swirl/fade GPU behavior tests; extend the existing state-test target with production Renderer contact/batch checks.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Original-look default and the relative feel of Force, Dye, Swirl and Fade | CTRL-02–04 | Numeric state tests and isolated GPU pixels cannot establish recognizable motion and look | Launch each app; stir at defaults, compare to `01-BASELINE.md`/original GIF; adjust one slider at a time while running, watch ongoing fluid for Swirl/Fade and the next stroke movement for Force/Dye; restore defaults by relaunching. |
| Small Mac window and iPhone landscape/iPad expanded HUD, live slider drag, retained canvas input | CTRL-02–04; D-01–D-03 | Bounds, hit testing, scroll reachability and layout require actual on-screen interaction | Open Tuning, inspect/read all four percentages and drag every slider; resize/rotate, scroll inside the HUD, change the field/pause action and drag immediately outside the HUD. Verify closed initially and sticky-open after canvas drag. |
| Physical two-finger and concurrent iOS contact behavior | CTRL-02–04 | Xcode 27 Device Hub cannot reproduce the documented two-finger gestures | Test on physical iOS device when available; record NOT TESTED otherwise, as the user approved this follow-up as non-blocking. |
| iPad UI automation | CTRL-02–04; D-01–D-03, D-08 | The iPad simulator UI runner timed out in Plan 03 and again on a focused nonparallel audit run; the user's approved live iPad check is separate | Retry a focused iPad `HUDUITests` case when the simulator runner is responsive; do not infer an automated pass from `simctl launch` or the user's live observation. |

---

## Validation Sign-Off

- [x] Every finalized behavior has an automated check or explicit manual-only exception; contact packing and the 11th-contact batch are covered by the production Renderer XCTest.
- [x] No three consecutive tasks without an automated verify step.
- [x] Shader behavior tests (including slower Fade and higher Swirl) exist and have run against the production Mac `default.metallib`.
- [x] Existing shared state, Mac UI, iOS UI and Metal test infrastructure can be extended without introducing a second simulation implementation.
- [x] No watch-mode commands.
- [x] `nyquist_compliant: true` after production Renderer packing/batching XCTest, numeric GPU/state/HUD checks and the attributed human observation. Physical multitouch and iPad UI automation remain separately NOT TESTED.

**Approval:** automated evidence and user-approved live-fluid/compact-layout observations recorded 2026-09-25 in `05-TUNING-VERIFICATION.md`; physical-device multitouch and iPad UI automation retain their separate NOT TESTED statuses.

## Validation Audit 2026-09-25

| Metric | Count |
|--------|-------|
| Gaps found | 2 |
| Resolved | 1 — production Metal readback now checks the 0% slow-Fade endpoint and 0/default/high Swirl |
| Escalated | 1 — no renderer-level test seam for contact packing or >10-contact batches; held-stroke behavior user-approved, batch case NOT TESTED |

**Fresh execution:** Mac `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` passed on the working tree (including pre-existing uncommitted Mac keyboard changes); `python3 -m unittest test_phase05_metal.py` passed after the GPU test additions. The default-parallel iPhone run timed out after 360 s without a result; a focused case and then the full iPhone HUD suite passed with `-parallel-testing-enabled NO`. A focused iPad UI case with parallel testing disabled timed out after 180 s without a result. The approved Mac/iPhone/iPad live matrix and previously recorded numeric readback remain attributed to `05-TUNING-VERIFICATION.md`; no fresh manual observation is claimed here.

## Validation Remediation 2026-09-25

| Metric | Count |
|--------|-------|
| Previously escalated Renderer gap | 1 |
| Resolved by production-code test | 1 — Force/Dye changes on the next movement, contact 11 in the second batch, and origin/empty sentinels |
| Remaining Phase 5 Nyquist gaps | 0 |

`RendererContactTests.swift` compiles `Shared/Renderer.swift` and its existing Metal support files into the Mac state-test target. The actual draw path and the tests both call `Renderer.contactBatches` and `Renderer.writeContacts`, including the second batch. The test-first run failed because these production methods were not accessible; after the minimal extraction, the full Mac result bundle recorded **16/16 passed** (11 state/Renderer tests, 5 Mac HUD UI tests): `/var/folders/nq/0xqx24zn7dn5qmzxkl4dyp9r0000gn/T/opencode/phase05-renderer-20260925.xcresult`. `python3 -m unittest test_phase05_metal.py` and the generic iOS Simulator app build passed after the shared Renderer change. A focused iPhone HUD test passed; two subsequent attempts at the full iPhone UI suite timed out without a result, so the previous recorded 6/6 iPhone suite remains the latest completed full-suite evidence. iPad UI automation and physical multitouch retain their prior NOT TESTED statuses.

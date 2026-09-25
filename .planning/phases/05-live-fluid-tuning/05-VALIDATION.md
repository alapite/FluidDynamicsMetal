---
phase: 5
slug: live-fluid-tuning
status: partial
nyquist_compliant: false
wave_0_complete: true
created: 2026-09-25
---

# Phase 5 — Validation Strategy

> Feedback and observation contract for CTRL-02, CTRL-03, CTRL-04 and decisions D-01–D-10. The audit below distinguishes passing behavior checks from the remaining renderer-level automation gap.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Production-state XCTest, Mac and iOS XCUITest, existing offscreen Metal/Python unittest harness, and manual GPU/interaction observation |
| **Config file** | `FluidDynamicsMetal.xcodeproj/project.pbxproj`, `FluidDynamicsMetalStateTests/SimulationStateTests.swift`, both platform `HUDUITests.swift` files and `test_phase03_metal.py` / `test_phase03_metal.swift` (existing Metal harness example) |
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
| 05-01 Task 1 / wave 1 | CTRL-02–04; D-04–D-10 | Four slider positions, bounds, default constants and inverse Fade mapping in `FluidDynamicsMetalStateTests/SimulationStateTests.swift`; real `Renderer.writeContacts` scaling and extra batches lack an isolated test | Mac quick run | **PARTIAL** — mapping green, renderer contact packing not automatically verified |
| 05-01 Task 2 / wave 1 | CTRL-02–04; D-01–D-10 | Mac disclosure, values and field/canvas behavior in `FluidDynamicsMetalOSXUITests/HUDUITests.swift`; real force/dye splats and 0/17/100% Fade, 0/default/high Swirl in `test_phase05_metal.swift` via `test_phase05_metal.py` | Mac quick run + focused GPU harness | **COVERED** for HUD and shader effects; compact layout and held-stroke feel separately observed, not asserted by GPU test |
| 05-02 Task 1 / wave 2 | CTRL-02–04; D-01–D-10 | iOS closed disclosure and default sliders in `FluidDynamicsMetaliOSUITests/HUDUITests.swift`; the same state/GPU tests exercise shared values and shaders | iPhone full-suite command + Mac/GPU commands | **PARTIAL** — iOS UI and shared behavior green, but no renderer-level automated contact path |
| 05-02 Task 2 / wave 2 | CTRL-02–04; D-01–D-03, D-08 | iPhone Hide/Reopen, pause/field, inside/outside HUD double taps and landscape reachability in `FluidDynamicsMetaliOSUITests/HUDUITests.swift` | iPhone full-suite command | **COVERED** on iPhone; iPad automation NOT TESTED (timeout) and live iPad behavior user-approved separately |
| 05-03 Task 1 / wave 3 | CTRL-02–04; D-04–D-10 | Execute Mac state/UI, iPhone UI and production-shader readback; evidence in `05-TUNING-VERIFICATION.md` and this audit | Mac quick run + focused GPU harness + iPhone full-suite command | **COVERED** for commands executed; prior matrix records original numeric values |
| 05-03 Task 2 / wave 3 | CTRL-02–04; D-01–D-10 | Blocking user observation checkpoint, Mac/iPhone/iPad matrix in `05-TUNING-VERIFICATION.md` | None (manual checkpoint) | **MANUAL-ONLY** — user-approved live behavior, physical multitouch NOT TESTED |

*Automated PASS is restricted to checks actually run; the Mac/iPhone/iPad live checks are separately attributed to the user's 2026-09-25 approval in `05-TUNING-VERIFICATION.md`. The GPU harness provides uniform bytes directly and does not exercise `Renderer.writeContacts` or extra-batch packing. No threat-model-specific external exposure is expected: controls modify only local in-memory solver state.*

---

## Wave 0 Requirements

- [x] Production-state XCTest and Mac/iPhone HUD XCUITest targets already exist in the two shared schemes.
- [x] Existing offscreen Metal regression demonstrates how to run compiled shaders on `rg16Float` textures without changing the app.
- [x] Add mapping/default tests and actual force/dye/swirl/fade GPU behavior tests during the corresponding implementation tasks; no new test target required for these checks.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Original-look default and the relative feel of Force, Dye, Swirl and Fade | CTRL-02–04 | Numeric state tests and isolated GPU pixels cannot establish recognizable motion and look | Launch each app; stir at defaults, compare to `01-BASELINE.md`/original GIF; adjust one slider at a time while running, watch ongoing fluid for Swirl/Fade and the next stroke movement for Force/Dye; restore defaults by relaunching. |
| Small Mac window and iPhone landscape/iPad expanded HUD, live slider drag, retained canvas input | CTRL-02–04; D-01–D-03 | Bounds, hit testing, scroll reachability and layout require actual on-screen interaction | Open Tuning, inspect/read all four percentages and drag every slider; resize/rotate, scroll inside the HUD, change the field/pause action and drag immediately outside the HUD. Verify closed initially and sticky-open after canvas drag. |
| Physical two-finger and concurrent iOS contact behavior | CTRL-02–04 | Xcode 27 Device Hub cannot reproduce the documented two-finger gestures | Test on physical iOS device when available; record NOT TESTED otherwise, as the user approved this follow-up as non-blocking. |
| Renderer Force/Dye contact packing and >10-contact batch reuse | CTRL-02; D-04–D-05 | The offscreen test writes shader uniforms itself; `Renderer.writeContacts` is private and the state-test target does not compile `Renderer.swift`. User-approved held-stroke behavior covers the observable path, but >10 contacts have no executable result | With an instrumented app-level renderer readback or a renderer test seam, inject a changing Force/Dye during a held contact, then 11 distinct contacts; check both independent zero cases and the 11th contact using the actual production `Renderer`. Until that harness exists, mark batch-specific coverage NOT TESTED. |
| iPad UI automation | CTRL-02–04; D-01–D-03, D-08 | The iPad simulator UI runner timed out in Plan 03 and again on a focused nonparallel audit run; the user's approved live iPad check is separate | Retry a focused iPad `HUDUITests` case when the simulator runner is responsive; do not infer an automated pass from `simctl launch` or the user's live observation. |

---

## Validation Sign-Off

- [ ] Every finalized behavior has an automated check or explicit manual-only exception; renderer contact packing remains an exception.
- [x] No three consecutive tasks without an automated verify step.
- [x] Shader behavior tests (including slower Fade and higher Swirl) exist and have run against the production Mac `default.metallib`.
- [x] Existing shared state, Mac UI, iOS UI and Metal test infrastructure can be extended without introducing a second simulation implementation.
- [x] No watch-mode commands.
- [ ] `nyquist_compliant: true` requires executable coverage for the production Renderer contact-packing path. This audit retains partial status; physical multitouch and iPad UI automation remain NOT TESTED.

**Approval:** automated evidence and user-approved live-fluid/compact-layout observations recorded 2026-09-25 in `05-TUNING-VERIFICATION.md`; physical-device multitouch and iPad UI automation retain their separate NOT TESTED statuses.

## Validation Audit 2026-09-25

| Metric | Count |
|--------|-------|
| Gaps found | 2 |
| Resolved | 1 — production Metal readback now checks the 0% slow-Fade endpoint and 0/default/high Swirl |
| Escalated | 1 — no renderer-level test seam for contact packing or >10-contact batches; held-stroke behavior user-approved, batch case NOT TESTED |

**Fresh execution:** Mac `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` passed on the working tree (including pre-existing uncommitted Mac keyboard changes); `python3 -m unittest test_phase05_metal.py` passed after the GPU test additions. The default-parallel iPhone run timed out after 360 s without a result; a focused case and then the full iPhone HUD suite passed with `-parallel-testing-enabled NO`. A focused iPad UI case with parallel testing disabled timed out after 180 s without a result. The approved Mac/iPhone/iPad live matrix and previously recorded numeric readback remain attributed to `05-TUNING-VERIFICATION.md`; no fresh manual observation is claimed here.

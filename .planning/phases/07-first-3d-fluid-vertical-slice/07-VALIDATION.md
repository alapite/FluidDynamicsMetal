---
phase: 7
slug: first-3d-fluid-vertical-slice
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-11-06
---

# Phase 7 — Validation Strategy

> Executable sampling contract mapped to nine reviewed plans on 2026-11-06. UI-SPEC is approved. `nyquist_compliant: true` means the planning/sampling contract is complete, **not** that implementation, tests, Wave 0 infrastructure or numerical acceptance have passed. `wave_0_complete` remains false until the required infrastructure is actually created/exercised.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | Existing XCTest/XCUITest; Python unittest driving a compiled production Swift/Metal harness |
| Configuration | `FluidDynamicsMetal.xcodeproj` and shared app schemes; no Swift package |
| Quick CPU command | `python3 -m unittest Tests.Integration.test_fluid3d_reference.ReferenceContractTests.test_quick_contract` — created by 07-01-02 |
| Production GPU command | `python3 -m unittest Tests.Integration.test_fluid3d` — harness created by 07-02, expanded alongside each feature; fresh Mac build first |
| Existing full integration | `python3 -m unittest discover -s Tests/Integration` — both fresh builds and applicable simulator availability required |
| Existing Mac state/HUD command | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` |
| Runtime / feedback latency | Unmeasured until execution. Target quick CPU/small GPU fixture feedback ≤30 seconds; full64 feasibility, compilation/builds, numerical soak, native UI and full regressions are explicitly slower acceptance gates, not a sub30-second promise. Measure/report quick and full durations separately. |

**Execution prerequisite:** Active Xcode 27.2 reports a missing Metal Toolchain when running `xcrun metal --version`. Run `xcodebuild -downloadComponent MetalToolchain` before fresh build/GPU verification. Research did not install it or run app builds/tests. An `xcrun --find metal` shim path is not proof the compiler works.

## Sampling Rate

- Every task: run its focused automated assertion. Numerical tasks use the independent CPU oracle and applicable production fixture; state tasks use state/renderer tests; native UI tasks use relevant HUD tests.
- Before kernel implementation: commit the numerical contract with independent CPU fixture/reference definitions and predetermined tolerances. Do not derive tolerances by fitting failed production results.
- After numerical changes: fresh Mac metallib build, then production GPU fixture. A CPU-only test cannot satisfy VER-03.
- After shared-mode/state changes: both no-override app builds and applicable existing 2D state/GPU regressions. iOS remains 2D-only.
- Every implementation wave: rerun applicable full integration and Mac state/HUD checks; use available iOS simulator destinations for applicable iOS HUD coverage.
- Before phase verification: all applicable tests green, actual result artifacts available, and unavailable hardware/runtime cases explicitly NOT TESTED.
- Use the mapped focused command below for each task, plus the quicker supplemental checks in its PLAN. All GPU checks follow a fresh Mac build; do not substitute an unrelated CPU pass for a production fixture. Never leave three consecutive implementation tasks without automated feedback.

## Per-Task Verification Map

Command aliases below name exact executable commands, not additional scripts:

- **REF(method):** `python3 -m unittest Tests.Integration.test_fluid3d_reference.ReferenceContractTests.<method>`.
- **GPU(method):** `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.<method>` after fresh Mac build. Each method is introduced in the task that first uses it; the Python/Swift harness always executes the production encoder/metallib, not a duplicate solver.
- **STATE:** focused Mac state invocation below.
- **MAC(method):** Mac scheme `xcodebuild test` command above with `-only-testing:FluidDynamicsMetalOSXUITests/HUDUITests/<method>`. Exact current target confirmed from the shared scheme.
- **IOS(method):** iOS scheme test with `-destination "platform=iOS Simulator,id=${IOS_SIMULATOR_ID:?Set a discovered ID}"` and `-only-testing:FluidDynamicsMetaliOSUITests/HUDUITests/<method>`; run discovered iPhone and iPad IDs separately.
- **EVIDENCE:** `python3 Tests/Integration/test_fluid3d.py --check-evidence --quick`; full check without `--quick` is mandatory in 07-08. Schema/hash checks do not generate numerical evidence.

| Task ID | Wave | Requirement(s) | Threat Ref | Correct behavior / automated command | Infrastructure status | Result |
|---|---|---|---|---|---|---|
| 07-01-01 | 1 | SIM-05, VER-03 | T-07-01/02 | Contract source assertion in PLAN (stdlib Python) before kernels | Existing Python; creates contract | Pending |
| 07-01-02 | 1 | SIM-05, VER-03 | T-07-01/02 | REF(test_quick_contract), REF(test_reference_feasibility); CPU Double oracle / fixture export | Creates reference Python + Swift files | Pending |
| 07-05-01 | 1 | SIM-04/06, LES-01/02/06 | T-07-11 | STATE: exact queue/reset/lifecycle, no-op fields, 2D preferences | Extends existing XCTest | Pending |
| 07-05-02 | 1 | SIM-06 | T-07-12 | IOS(testExperimentMenuRemainsTwoDOnly); supplemental existing settings test | Extends existing iOS HUD | Pending |
| 07-02-01 | 2 | SIM-05, VER-03 | T-07-03/05 | GPU(test_storage_and_abi): checked dimensions/strides/ABI/error paths | Creates production Python + Swift harness | Pending |
| 07-02-02 | 2 | SIM-05, VER-03 | T-07-04 | GPU(test_advection_and_boundaries): all axes and reflected six-face sampling | Adds fixture to same harness | Pending |
| 07-03-01 | 3 | SIM-05, VER-03 | T-07-06 | GPU(test_operators): independent D/G/A, all edges/corners and finite reductions | Adds fixture | Pending |
| 07-03-02 | 3 | SIM-05, VER-03 | T-07-06/07 | GPU(test_projection): true residual AND divergence, gauge, failure/cap/status | Adds fixture | Pending |
| 07-03-03 | 3 | SIM-05, VER-03 | T-07-08 | GPU(test_reset_and_finite): one-step reference, full scratch/generations/600 soak | Adds fixture | Pending |
| 07-04-01 | 4 | SIM-05, VER-03 | T-07-09 | GPU(test_slice_and_palette): midpoint31/32, orientation/colors/read-only fields | Adds fixture | Pending |
| 07-04-02 | 4 | SIM-05, VER-03 | T-07-10 | GPU(test_evolution_and_visibility): full components/depth/nonplanarity and early captures | Adds fixture | Pending |
| 07-06-01 | 5 | SIM-06, VER-03 | T-07-13 | `python3 -m unittest Tests.Integration.test_educational_release Tests.Integration.test_renderer_correctness`: compile old consumers | Updates two existing source lists / memberships | Pending |
| 07-06-02 | 5 | SIM-04/06 | T-07-13/15 | GPU(test_transitions_and_failures): real rollback/retry/semaphore/full-mode state | Adds fixture and injectable production seams | Pending |
| 07-06-03 | 5 | LES-01/02/06 | T-07-14/15 | GPU(test_renderer_steps_and_inactivity): actual nil-drawable steps, settled inactive state, no catch-up | Adds controlled-callback production-renderer fixture | Pending |
| 07-07-01 | 6 | SIM-04/06, LES-01/02 | T-07-16/18 | MAC(testThreeDGroupedNavigationAndTransport), MAC(testThreeDInitializationFailureRestoresTwoD) | Extends existing Mac HUD | Pending |
| 07-07-02 | 6 | SIM-04/06, LES-01/02/06 | T-07-17 | MAC(testThreeDPanelFocusAndReturn), MAC(testThreeDPanelLayoutPreservesState) | Extends existing Mac HUD | Pending |
| 07-08-01 | 7 | VER-03, SIM-05 | T-07-19/20 | GPU(test_evidence_schema); `python3 Tests/Integration/test_fluid3d.py --benchmark` | Adds schema test/benchmark/evidence CLI | Pending |
| 07-08-02 | 7 | All seven | T-07-19/21 | EVIDENCE plus full matrix in PLAN: both builds, Mac/iOS suites, full integration | Uses prior fixtures; writes actual report | Pending |
| 07-09-01 | 8 | All seven | T-07-22 | EVIDENCE; prepare current launchable app and captures | Prior fixtures + existing build script | Pending |
| 07-09-02 | 8 | All seven | T-07-22 | Blocking human review plus EVIDENCE supporting check; **not** automatable visual approval | Explicit checkpoint; records user response | Pending |

No implementation task relies on an unassigned MISSING test. Creator tasks own their tests and observe failure before implementing production behavior; later tasks depend on their creator plans. All 20 tasks have automated checks, including the human checkpoint's supporting check (which cannot approve it). Wave 0 means test-infrastructure responsibility, not a separate parallel execution wave.

Focused existing Mac state invocation, after required source memberships are wired:

```bash
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO -only-testing:FluidDynamicsMetalStateTests
```

## Wave 0 Requirements

- [ ] `docs/3d-numerical-contract.md`: coordinates, face/cell locations, units/dt/pass order, precision/ABI, interpolation/ghost rules, all six walls, compatible D/G/A and pressure gauge, solver termination/failure semantics, independent reference fixtures and final tolerances.
- [ ] `Tests/Integration/test_fluid3d_reference.py` / `fluid3d_reference.swift` (07-01-02): independent CPU Double fixtures, asymmetric axes, boundaries/corners, nullspace and manufactured references; no Metal imports/calls, before kernels. Includes real64 feasibility gate and export.
- [ ] `Tests/Integration/test_fluid3d.py` and `.swift`: production-source compilation and fresh app metallib loading, 3D upload/readback, focused numerical/scheduler fixtures, Metal validation and structured artifacts.
- [ ] State/mobile HUD additions in 07-05, production renderer fixtures in 07-06 and Mac grouped/focus/recovery HUD additions in 07-07.
- [ ] Injectable construction/reset failure path in 07-06 with native alert proof in 07-07; complete callback/generation/failure coverage uses T-07-13–18.
- [ ] Source membership added with each new file in 07-02–04 and compiling-consumer audit in 07-06-01; both existing renderer source lists included.
- [ ] Working active Metal Toolchain; currently missing. No new third-party test framework is required.

## Numerical and Performance Evidence Contract

- Use `07-RESEARCH.md`'s numerical contract recommendations to define CPU/reference fixture values **before** kernel implementation and record them in `docs/3d-numerical-contract.md`.
- Production evidence includes all three velocity fields, dye, pressure/correction and solver scratch/status; true residual, post-projection divergence (max and L2), wall-normal flux, mean compatibility, convergence iterations/cap hits and explicit finite checks.
- Validate even-grid midpoint at world Z=.5 (equal interpolation of cell planes 31/32), X/Y orientation and fixed amber concentration mapping with asymmetric scalar fixtures.
- Calibrate and record the real recipe's readable early window with fixed-plane captures and nonplanar field/transport metrics. Steps 0/24/48/72 are proposed captures, not demonstrated visibility or speed-ordering results.
- Baseline solver-only and solver-plus-fixed-slice separately at 64³ and 1280×720 output, proposed 60 warm-up / 240 measured advances. Record host/config, GPU timings, host timing distributions, solver quality and resources. Readback/captures outside timing.
- Offscreen timing does not establish presentation frame rate. Record an actual displayed-frame interval sample separately if available. Phase 10 retains the 30 fps gate and tracer/volume performance contract.
- Keep actual outcomes in `docs/3d-phase7-verification.md`; do not rewrite historical educational-release results as new evidence.

## Required Regression Builds

```bash
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

No Swift-version or deployment-target overrides. Run full existing applicable integration checks after builds. Discover current iOS test destinations via `xcrun simctl list devices available`; do not reuse historical IDs or claim a generic build establishes HUD/device behavior.

## Manual-Only / Visual Verifications

| Behavior | Requirement / decision | Why manual review supplements automation | Instructions |
|---|---|---|---|
| Readable tumbling transport and factual copy | SIM-05; D-03–10, D-13 | Pixel/field assertions alone do not establish understandable visual character | Inspect step 0 and declared early captures: one amber patch, fixed square face-on XY plane, no canvas orientation overlays; note dye leaving the plane and numerical smoothing honestly |
| Native focus, group headings and recovery explanation | SIM-04/06; D-01/02/11/12/14 | Automated UI checks cover routing; native interaction/accessibility still deserves review | Select through panel and menu, verify Command-1–4 unchanged, S no-op in 3D, focused-control Space consumed once, hidden unsupported sections, clear injected-failure error and usable 2D fallback |
| Minimize/deactivate and return | LES-06 | Controlled renderer tests cover counters/state; real window/lifecycle routing also needs observation | Repeat with running and manually paused 3D; freeze during inactivity, retained pause choice, no catch-up jump after return |
| Actual macOS 26 runtime | Deferred historical compatibility coverage | Available host runs macOS 27 | NOT TESTED until exercised on actual macOS 26 with usable Metal; do not close using current host |
| Physical iOS multitouch | Deferred historical mobile coverage | Requires physical hardware | NOT TESTED without hardware; no mobile 3D exposure in this phase |

## Validation Sign-Off

- [x] UI-SPEC gate satisfied; executable plans created and reviewed inline.
- [x] Actual plan/task IDs, waves, threat references and automated commands replace provisional mapping.
- [x] Every task has automated verification and test-infrastructure creation is assigned before dependent use.
- [x] No three consecutive tasks without automated feedback; no watch-mode commands.
- [x] Missing test files/framework wiring covered by creator tasks; no new test framework dependency.
- [ ] Quick/full feedback latency measured and documented; expensive suites separated honestly.
- [ ] Numerical reference/acceptance contract fixed before production acceptance; no residual-only projection pass.
- [ ] Required builds/tests executed and result artifacts reviewed; unavailable coverage labelled.
- [x] `nyquist_compliant: true` denotes completed executable sampling design, not tests passing.

**Approval:** Planning/sampling contract approved 2026-11-06 after inline plan checking. Implementation, test infrastructure execution, measured feedback latency, numerical acceptance and human approval remain PENDING. These unchecked execution items do not become green merely because the plans pass review.

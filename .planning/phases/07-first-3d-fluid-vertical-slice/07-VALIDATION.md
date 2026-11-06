---
phase: 7
slug: first-3d-fluid-vertical-slice
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-11-06
---

# Phase 7 — Validation Strategy

> Draft validation contract derived from `07-RESEARCH.md`. Plan creation is paused at the missing UI-SPEC gate. No plan/task IDs or passing execution evidence are implied.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | Existing XCTest/XCUITest; Python unittest driving a compiled production Swift/Metal harness |
| Configuration | `FluidDynamicsMetal.xcodeproj` and shared app schemes; no Swift package |
| Proposed quick command | `python3 -m unittest Tests.Integration.test_fluid3d_reference` — new file required |
| Proposed production GPU command | `python3 -m unittest Tests.Integration.test_fluid3d` — new Python/Swift harness required; fresh Mac build first |
| Existing full integration | `python3 -m unittest discover -s Tests/Integration` — both fresh builds and applicable simulator availability required |
| Existing Mac state/HUD command | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` |
| Runtime / feedback latency | Not measured for the new fixtures; target quick CPU feedback ≤30 seconds, then measure and record actual timings |

**Execution prerequisite:** Active Xcode 27.2 reports a missing Metal Toolchain when running `xcrun metal --version`. Run `xcodebuild -downloadComponent MetalToolchain` before fresh build/GPU verification. Research did not install it or run app builds/tests. An `xcrun --find metal` shim path is not proof the compiler works.

## Sampling Rate

- Every task: run its focused automated assertion. Numerical tasks use the independent CPU oracle and applicable production fixture; state tasks use state/renderer tests; native UI tasks use relevant HUD tests.
- Before kernel implementation: commit the numerical contract with independent CPU fixture/reference definitions and predetermined tolerances. Do not derive tolerances by fitting failed production results.
- After numerical changes: fresh Mac metallib build, then production GPU fixture. A CPU-only test cannot satisfy VER-03.
- After shared-mode/state changes: both no-override app builds and applicable existing 2D state/GPU regressions. iOS remains 2D-only.
- Every implementation wave: rerun applicable full integration and Mac state/HUD checks; use available iOS simulator destinations for applicable iOS HUD coverage.
- Before phase verification: all applicable tests green, actual result artifacts available, and unavailable hardware/runtime cases explicitly NOT TESTED.
- Finalize per-task commands, Wave 0 dependencies and measured feedback latency after plans exist. Never leave three consecutive implementation tasks without automated feedback.

## Per-Task Verification Map

Executable plan/task IDs and waves are deliberately **unassigned**: the workflow has not reached planning. Replace this requirement-level map with actual task IDs when the UI-SPEC gate is satisfied and plans are created.

| Requirement | Threat Ref | Secure / correct behavior | Test type | Automated command | File exists | Status |
|---|---|---|---|---|---|---|
| SIM-04 | GPU-INIT / MODE-ID | Nonselectable group headings; stable mode selection; native error restores usable 2D | Mac UI + renderer | Mac state/HUD command above; `python3 -m unittest Tests.Integration.test_fluid3d` | Existing suites need extensions; 3D harness missing | Pending |
| SIM-05 | GPU-BOUNDS / GPU-FINITE | Correct 64³/face extents, actual three-component evolution, depth variation, measured nonplanar transport | CPU + production GPU | `python3 -m unittest Tests.Integration.test_fluid3d_reference Tests.Integration.test_fluid3d` | Missing — Wave 0 | Pending |
| SIM-06 | MODE-ID / GPU-INIT | All 3D→2D paths clear stale contacts/queued steps and restore established preferences/defaults; failure cannot strand app | State + renderer + UI | Mac state/HUD command; `python3 -m unittest Tests.Integration.test_fluid3d Tests.Integration.test_educational_release` | Existing suites need extensions; 3D harness missing | Pending |
| LES-01 | STEP-STATE | Paused Step 0, Run/Pause/Resume, accurate counter, presentation-only redraw does not advance | State + renderer + UI | Mac state/HUD command; `python3 -m unittest Tests.Integration.test_fluid3d` | Existing suites need extensions; 3D harness missing | Pending |
| LES-02 | STEP-STATE | Each accepted paused action → exactly one encoded advance, including rapid queues/nil drawable; failed encode is not success | State + renderer | Mac state test selection below; `python3 -m unittest Tests.Integration.test_fluid3d` | Existing state suite needs extensions; 3D harness missing | Pending |
| LES-06 | STEP-STATE | Full numerical state frozen while inactive, queued work cancelled, pause intent retained, no catch-up | State + renderer | Mac state test selection below; `python3 -m unittest Tests.Integration.test_fluid3d` | Existing state suite needs extensions; 3D harness missing | Pending |
| VER-03 | GPU-BOUNDS / GPU-FINITE | Independent oracle, compatible operators, true residual AND divergence, all axes/six walls, finite state/status | CPU + production GPU | `python3 -m unittest Tests.Integration.test_fluid3d_reference Tests.Integration.test_fluid3d` | Missing — Wave 0 | Pending |

Threat names here identify provisional verification concerns, not finalized plan threat IDs. Each eventual plan must provide its own `<threat_model>` and connect mitigations to executable verification.

Focused existing Mac state invocation, after required source memberships are wired:

```bash
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO -only-testing:FluidDynamicsMetalStateTests
```

## Wave 0 Requirements

- [ ] `docs/3d-numerical-contract.md`: coordinates, face/cell locations, units/dt/pass order, precision/ABI, interpolation/ghost rules, all six walls, compatible D/G/A and pressure gauge, solver termination/failure semantics, independent reference fixtures and final tolerances.
- [ ] `Tests/Integration/test_fluid3d_reference.py`: CPU Double fixtures with asymmetric axes, boundaries/corners, pressure nullspace and manufactured references; runnable before 3D kernels exist.
- [ ] `Tests/Integration/test_fluid3d.py` and `.swift`: production-source compilation and fresh app metallib loading, 3D upload/readback, focused numerical/scheduler fixtures, Metal validation and structured artifacts.
- [ ] State/HUD additions for grouped mode navigation, S no-op/focus semantics, 3D transport/lifecycle and preserved 2D behavior.
- [ ] Injectable GPU construction/reset failure path and corresponding assertions for native error, fallback mode and synchronization recovery.
- [ ] Explicit source membership in both apps / relevant state-test target and every existing standalone harness source list affected by renderer references.
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

- [ ] UI-SPEC gate satisfied; executable plans created and reviewed.
- [ ] Actual plan/task IDs, waves, threat references and automated commands replace the provisional mapping.
- [ ] Every task has automated verification or an explicit Wave 0 dependency.
- [ ] No three consecutive tasks without automated feedback; no watch-mode commands.
- [ ] Missing test files/framework wiring covered by Wave 0 tasks.
- [ ] Quick/full feedback latency measured and documented; expensive suites separated honestly.
- [ ] Numerical reference/acceptance contract fixed before production acceptance; no residual-only projection pass.
- [ ] Required builds/tests executed and result artifacts reviewed; unavailable coverage labelled.
- [ ] `nyquist_compliant: true` set only after the executable sampling contract is complete.

**Approval:** Pending — research-derived draft; no implementation or plan verification performed.

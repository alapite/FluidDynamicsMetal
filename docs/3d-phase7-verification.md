# Phase 7 — 3D Dye-Advection Verification

**Status:** Automated evidence PASS. The 07-09 manual visual/accessibility/native-interaction review was **NOT PERFORMED**. On 2026-11-13 the user directed closeout to proceed on the assumption that the review would find no issues; this is an administrative disposition, not an observed result or human-review PASS. **SIM-04, SIM-05, SIM-06, LES-01, LES-02, and LES-06 remain pending manual acceptance. VER-03 is complete from its production-kernel evidence.** This report does not claim Phase 10 performance qualification.

- **Evidence date:** 2026-11-08
- **Host:** Mac15,6, Apple M3 Pro, arm64; macOS 27.0 (26A428); Xcode 27.2 (27B52); Apple Swift 6.4.2; Debug configuration.

## Scope and reproducibility

The delivered slice is the Mac-only, genuine 64³ dye-advection lesson with one fixed, face-on XY section at world Z=0.5 (equal weights on cell planes 31 and 32). Dye uses the fixed amber concentration palette. Selecting the lesson opens it paused at step 0; this does not deliver the later camera, tracer, speed-comparison, full teaching/completion flow, or volume-rendering features.

The numerical contract is `docs/3d-numerical-contract.md`. (Historical — superseded by the gap-closure re-verification: the complete-contract, metallib and inventory figures in this paragraph are the 2026-11-08 values.) Its preregistered-prefix SHA-256 is `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`; the complete amended contract SHA-256 is `5fdc33b839d7f135a828ac9e6e3c3b4e7adba03d5341771ddbed4b13767951a8`. Production evidence used metallib SHA-256 `d1ad2a54a5d48cc2b15cebd3c3142fe2a9334dc5e18957e8079202f3cefc4d79`, reference-manifest SHA-256 `3839a295cd2cb53ad97d52747f5960598143a37c9cc9bac65fd75a16d8030ba9`, and a 21-file source-hash inventory. The machine-readable manifests contain the per-file hashes and artifact paths.

The benchmark protocol was preregistered: same reset seed and contracted `dt=1/60`/pressure settings in both configurations; 64³ grid; three-command in-flight limit; 60 warm-up advances then 240 measured advances; explicitly allocated 1280×720 `bgra8Unorm` output with a centered 720×720 viewport at `(280,0)`. Readback, pre/post numerical validation, and Metal validation were excluded from timed samples; statuses were checked for all warm-up and measured advances. The complete inventory records solver, pressure/reduction/status, staging, retained 2D, slice geometry, and output resources.

## Requirement-to-evidence matrix

Automated evidence is reported separately from manual observations. “PASS” below describes the listed automated evidence only. The user's no-issues assumption is not treated as a manual observation or approval. The six user-facing requirements remain **PENDING** manual acceptance; VER-03 is satisfied by its automated production-kernel criterion.

| Requirement | Automated evidence (PASS) | Human-review status |
|---|---|---|
| **SIM-04** — select the 3D lesson on Mac | Mac HUD tests exercise grouped 2D/3D navigation, menu/selector synchronization, committed mode identity, and preparation failure handling. See `mac-tests-07-08.xcresult` and the retained 07-07 UI bundle `mac-tests-final.xcresult`. | **NOT PERFORMED; PENDING** — inspect the native selector and Simulation menu in the running app. |
| **SIM-05** — genuine evolving 64³ flow with depth variation/nonplanar transport | Production `advection-boundaries`, `operators`, `projection`, `reset-finite`, `slice-palette`, and `evolution-visibility` fixtures passed. Three velocity components evolve; the full-volume unequal-axis dye reference moved 5.7856 cells in Z over 48 steps (CPU reference 5.7862 cells). Depth variation was 0.10589 (0.8824 of reset speed maximum). The independent curved reference trajectory's best-fit-plane RMS/arc-length was 0.01662 against the preregistered 0.01 minimum. | **NOT PERFORMED; PENDING** — inspect contained tumbling transport and the fixed-slice appearance; screenshots alone do not establish the lesson's visual character. |
| **SIM-06** — return to established 2D modes without stale input | `transitions-and-failures` passed injected allocation, pipeline, reset, and wrong-grid cases; it verified rollback/retry and return to all four 2D modes. Mac HUD tests exercise native fallback and retry. | **NOT PERFORMED; PENDING** — exercise the native recovery message, continue in 2D, retry, and verify the 2D controls in the running app. |
| **LES-01** — enter paused at step 0 and Run/Pause/Resume with a step count | Production renderer-step fixtures and Mac HUD tests passed; entry/reset state is seeded, paused, and step 0. Inactivity assertions are separately listed under LES-06. | **NOT PERFORMED; PENDING** — inspect the visible counter and transport. |
| **LES-02** — one logical advance per paused Step action | Production renderer tests passed exact queued-step, nil-drawable, paused-redraw, resize, and mode-transition checks. The renderer fixture reports exact advances `[1,31]` in its two cases; no redraw/resize step was introduced. | **NOT PERFORMED; PENDING** — manually exercise Step and confirm the displayed count. |
| **LES-06** — inactivity without advancement or catch-up | Controlled production-renderer checks passed while running and manually paused; activation did not cause catch-up, pending input was cleared, and stale completion after mode transition was ignored. | **NOT PERFORMED; PENDING** — manually deactivate/minimize and return while running and manually paused. |
| **VER-03** — production-kernel checks for advection, projection, boundaries, and finite fields | Fresh-Metal production fixtures passed across all three axes, six walls, edges/corners, projection, finite-field, ABI, reset, and slice checks. Numerical detail is below; the complete evidence is under `.build/fluid3d-evidence/`. | **COMPLETE** on automated production-kernel evidence. This status does not imply visual review of the lesson. |

## Production numerical results

The full production GPU fixture suite passed on the Apple M3 Pro. The Swift/Metal ABI fixture compared 5,960 values and confirmed 48-byte uniform stride, 16-byte alignment, and offsets 0/16/32. The 11 advection/boundary cases (positive and negative X/Y/Z, combined XYZ, wall/edge/corner, and production mixed flow) were finite; maximum elementwise absolute error was `2.114e-7`; wall-normal velocity was exactly zero. Operator checks reported maximum operator error `4.251e-7`, maximum divergence-operator error `3.376e-9`, maximum identity error `2.086e-7`, net wall flux zero, and maximum wall-normal value zero.

Projection gates are `dt·||D u_new||∞ ≤ 1e-5` and `dt·||r||∞/h² ≤ 1e-5`; the full-grid wall/edge/corner case retained the locked 320-iteration cap. The table includes pre/post max divergence in timestep-scaled units, the production and independently recomputed true-residual max, and raw independent divergence/residual RMS values as emitted by the fixture (RMS fields are not the timestep-scaled infinity gates).

| Projection fixture | Input `dt·||Du*||∞` | Post `dt·||Du_new||∞` | True residual `dt·||r||∞/h²` (GPU / independent) | Independent divergence RMS | Independent residual RMS | Iterations | RHS mean | Max wall-normal | Cap hit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Zero RHS | 0 | 0 | 0 / 0 | 0 | 0 | 0 | 0 | 0 | No |
| Constant pressure | 0 | 0 | 0 / 0 | 0 | 0 | 0 | 0 | 0 | No |
| Alternating pressure | 102.400009 | 2.919195e-6 | 0 / 2.919195e-6 | 1.282145e-4 | 3.130236e-8 | 2 | 0 | 0 | No |
| Manufactured cosine | 2.295520 | 1.174621e-6 | 1.017253e-6 / 1.174621e-6 | 7.349941e-6 | 1.794419e-9 | 180 | 0 | 0 | No |
| Mixed-frequency asymmetric | 0.015962 | 9.546678e-7 | 9.551645e-7 / 9.552601e-7 | 9.016733e-6 | 2.201141e-9 | 234 | -1.266e-14 | 0 | No |
| Wall/edge/corner | 18.421335 | 2.288818e-6 | 1.017253e-6 / 2.571470e-6 | 8.364411e-6 | 1.741118e-9 | **317** | 2.910e-11 | 0 | No |
| Divergence-free | 5.086263e-7 | 5.086263e-7 | 5.086263e-7 / 5.086263e-7 | 5.865042e-6 | 1.431895e-9 | 0 | 0 | 0 | No |

All seven projection fixtures were finite and converged without cap hits; maximum iteration count was 317/320. All six wall-normal faces were exactly zero in the recorded cases. Every nontrivial result met both `1e-5` infinity gates, and cases whose input divergence exceeded `1e-3` exceeded the required 1000× reduction. The full fixture also exercises incompatible RHS, nonfinite input, nonpositive denominator, and cap-failure paths and verifies distinct in-flight status slots.

The 600-step finite soak passed (125.998 seconds, maximum projection iteration count 144); one-step reference matching, uniform-dye preservation, and queued-failure freezing passed. `slice-palette` confirmed the `z=0.5` slice samples planes 31/32 with weights 0.5/0.5, X right/Y up, and presentation-only rendering at multiple viewport sizes.

## Early recipe window and captures

> **Historical — superseded by the gap-closure re-verification (2026-11-22, below).** This table and these captures describe the 2026-11-08 recipe (seed speed 0.17, smaller blob).

The early window is steps 0/24/48/72. The fixture also preserved a step-1 capture. It uses the fixed concentration scale: no explicit dye decay, per-frame brightness normalization, replenishment, or moving slice. A step is a solver advance, not seconds or a display frame.

| Step | Slice peak | Slice samples ≥0.02 | RMS difference from step 0 |
|---:|---:|---:|---:|
| 0 | 0.963842 | 141 | 0 |
| 24 | 0.881776 | 157 | 0.029350 |
| 48 | 0.807497 | 169 | 0.052411 |
| 72 | 0.770581 | 177 | 0.069309 |

All tested recipe states were finite, projection-converged, and cap-hit-free. The initial volume had one connected dye component. Normalized velocity changes were `u=0.22664`, `v=0.20710`, `w=0.16033` of the reset speed maximum; depth variation was `0.88242` of that maximum. The maximum dye-seeded probe Z travel was 3.238 cells. Separately, the analytic 48-step curved trajectory measured plane-RMS/arc-length `0.016624` (minimum `0.01`). These are numerical/visibility observations, not a human judgment that the animation reads as tumbling.

Captures and state dumps:

- `.build/fluid3d-evidence/recipe-step-000.ppm`, `recipe-step-024.ppm`, `recipe-step-048.ppm`, `recipe-step-072.ppm`
- Matching `.f32le` volume/state captures: `recipe-state-step-000.f32le`, `-024.f32le`, `-048.f32le`, `-072.f32le` in the same directory
- Additional step-1 image/state capture is also retained. The manifest is `.build/fluid3d-evidence/evolution-visibility.json`; the concise observation manifest is `recipe.json`.

## Early solver/slice performance baseline

> **Historical — superseded by the gap-closure re-verification (2026-11-22, below).** These figures predate the 6571fc5 indirect-dispatch iteration gate and the 07-15 recipe.

This is an offscreen solver baseline with and without the fixed-slice render pass; it is not displayed frame rate and it is not the later slice-plus-tracer/volume-plus-tracer qualification. The benchmark disables Metal validation during timed samples, keeps status validation active, and performs numerical pre/post checks separately. GPU command timings and host durations are separate measurements.

| Configuration (240 measured advances) | GPU ms median / p95 / max | Host encode ms median / p95 / max | Host submit ms median / p95 / max | Host completion ms median / p95 / max | PCG iterations median / p95 / max | Cap hits / failed statuses |
|---|---:|---:|---:|---:|---:|---:|
| Solver only | 161.410 / 164.311 / 166.331 | 4.720 / 10.463 / 15.145 | 0.0048 / 0.0146 / 0.0496 | 317.733 / 478.015 / 485.017 | 129 / 132 / 134 | 0 / 0 |
| Solver + fixed slice | 317.521 / 475.765 / 480.063 | 4.730 / 11.431 / 17.793 | 0.0052 / 0.0250 / 0.0543 | 317.802 / 476.164 / 480.404 | 129 / 132 / 134 | 0 / 0 |

The output allocation was 3,997,696 bytes (`1280×720 bgra8Unorm`); the centered fixed-slice viewport was 720×720. Resource inventory: 32 3D ping/pong textures (42,008,576 bytes); pressure/reduction/status data including high/low pressure textures, 32,768-byte reduction workspace, 16,640-byte reduction length, 304-byte status slots (up to three in flight), and failure/projection latches; 33,964,288 bytes of transient readback staging with no timed-segment readback; 12 retained 2D textures (47,972,352 bytes) and 133,196 bytes of retained 2D buffers; 64-byte slice vertex and 12-byte index buffers. Metal pipeline allocation is driver-managed and does not expose a byte count.

Displayed frame pacing is **NOT MEASURED**. No FPS claim is made; offscreen completion time is not presentation cadence. Phase 7 has no 30-fps gate, and this run does not satisfy or replace Phase 10's performance requirement.

## Regression matrix and retry history

The final applicable regression results are recorded in `.build/fluid3d-evidence/regression-matrix.json`; it includes exact commands, per-log SHA-256 values, result-bundle paths, and retry history.

| Check | Final result | Recorded outcome |
|---|---|---|
| Mac Debug build | **PASS**, exit 0 | Exact no-override scheme command; log `.build/fluid3d-evidence/logs/mac-build-final.log`. |
| iOS Simulator Debug build | **PASS**, exit 0 | Exact no-override scheme command; log `.build/fluid3d-evidence/logs/ios-build-final.log`. |
| Mac state + HUD | **PASS**, 40/40 | 25 state + 15 Mac HUD tests; `.build/fluid3d-evidence/mac-tests-07-08.xcresult`. |
| Full integration | **PASS**, 28/28 in 572.001 s | `python3 -m unittest discover -s Tests/Integration`; `.build/fluid3d-evidence/logs/integration-07-08.log`. |
| iPhone HUD simulator | **PASS**, 11/11 final | iPhone 17 Pro, iOS 26.4 simulator. Initial full run was 9/11: landscape fade remained at 17%, and large-text layout followed an interrupted orientation state. Each failing test passed in a focused retry; a subsequent full run passed 11/11 without source changes. Logs and all `.xcresult` attempts are retained in the matrix. |
| iPad HUD simulator | **PASS**, 11/11 final | iPad Pro 13-inch (M5), iOS 26.4 simulator. Initial run was 8/11; three orientation/layout assertions found the simulator had not rotated. The failure reproduced before reboot; focused orientation retry and full 11/11 run passed after reboot, with no source changes. Logs and `.xcresult` attempts are retained in the matrix. |
| Evidence schema test | **PASS**, 1/1 | `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_evidence_schema`. |

Both initial simulator-suite failures and their successful focused/full retries are preserved; neither was hidden or changed into a source fix. The earlier 07-07 light/dark and Simulation-menu UI attachments remain in `.build/fluid3d-evidence/mac-tests-final.xcresult`. Historical educational-release results were not rewritten.

After the report and README edits, final evidence validation passed:

- `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_evidence_schema` — **PASS**, 1/1.
- `python3 Tests/Integration/test_fluid3d.py --check-evidence --quick` — **PASS**, required files/schema/hashes current; this check makes no numerical claim.
- `python3 Tests/Integration/test_fluid3d.py --check-evidence` — **PASS**, current production fixture evidence and regression matrix validated; manual visual review was **NOT PERFORMED**.

## Coverage and deferred manual-review checklist

| Coverage item | Status | Limitation |
|---|---|---|
| Actual macOS 26 runtime | **NOT TESTED** | This Mac is running macOS 27.0; a newer host does not establish macOS 26 runtime behavior. |
| Physical iPhone/iPad multitouch | **NOT TESTED** | No physical-device multitouch exercise was performed. Simulator HUD tests are not physical-device gesture evidence. |
| Displayed frame pacing | **NOT MEASURED** | Benchmark configurations are offscreen. |
| Native visual, accessibility, and real-window interaction review | **NOT PERFORMED** | The user directed closeout to proceed on an assumption of no issues. No screenshot or automated test is treated as approval; the unchecked checklist below remains available for later review. |

### User-directed disposition (2026-11-13)

The user said they are too busy to know when they can carry out manual checks, asked for a document explaining what to check, and directed us to proceed assuming there are no issues. Accordingly, the 07-09 documentation closeout proceeds under that assumption. **No manual visual, accessibility, or real-window interaction checks were performed; no observations were made, and no issues were reported because the checks were not run. This is not explicit visual approval and must not be described as a human-review PASS.** Six user-facing Phase 7 requirements therefore remain pending manual acceptance. VER-03 is complete from the automated evidence above.

### Checklist for a later manual review

This checklist is a handoff for when the user has time. **Every item remains unchecked; none was performed as part of this closeout.** No command-line work is required.

- [ ] **Select the lesson and read the panel.** In the Experiments/Simulation controls, check the grouped 2D/3D headings, the active 3D Dye Advection selection, and the unchanged old titles/Command-1–4 behavior. On entry, check paused Step 0, the single amber patch on the square black canvas, and readable “XY slice · halfway through Z,” concentration legend, and factual note. Confirm there are no canvas axes/cube/text or unsupported 2D controls.
- [ ] **Watch transport and exercise playback.** Step, Run, Pause, and Resume; check the visible step count and that early flow reads as contained rolling/tumbling motion. Compare with the prepared 0/24/48/72 captures if useful. Remember that dye can thin or leave the fixed section, brightness represents concentration, and a solver step is neither physical time nor a display frame.
- [ ] **Check keyboard, focus, panel, and appearance/accessibility.** With canvas focus, confirm `S` does nothing and Space toggles once. Try Space on focused Step/Run/pop-up controls and ensure only their native action occurs. Move, close/reopen, scroll, and resize the panel/canvas, including a narrow panel; verify no reset, clipping, or hidden factual copy. Inspect Light/Dark, keyboard navigation, Increase Contrast, reduced transparency, and accessible labels where available; record each setting you cannot exercise.
- [ ] **Check inactivity and return to 2D.** Deactivate/minimize and return while 3D is running and while manually paused; confirm pause intent is preserved and no catch-up occurs. Return to each 2D mode and check established controls/defaults, fresh running Free Play preferences/input, and no stale forces.
- [ ] **Check the one-shot failure recovery.** The prepared Debug launch has `--fluid3d-test-failure=reset` armed but not triggered. Select 3D once; check the native “Couldn’t open 3D Dye Advection” alert, Continue in 2D acknowledgement, usable 2D selection/canvas, and a successful retry. Do not interpret a blank or fake 3D view as success.

Actual macOS 26 runtime and physical iPhone/iPad multitouch are not prerequisites for this Mac checklist and remain **NOT TESTED**. Displayed frame pacing remains **NOT MEASURED**. Do not infer later camera, tracer, speed-comparison, full replay, completion, or volume-rendering features.

**07-09 app preparation:** **READY**. `./build-macos.sh` succeeded and copied the fresh Debug app to `/Users/abiola/Documents/Code/Swift/FluidDynamicsMetal/FluidDynamicsMetalOSX.app`. Bundle identifier is `com.andreisergiupitis.FluidDynamicsMetalOSX`, version `1.0` (build `1`), arm64. The executable SHA-256 is `398ec38146ce001cd0b64824a70c410463cf00c56d9c6aa02551292e2ba1476e`; its `default.metallib` SHA-256 is `d1ad2a54a5d48cc2b15cebd3c3142fe2a9334dc5e18957e8079202f3cefc4d79`, identical to the production GPU evidence. The app was launched on the Apple M3 Pro/macOS 27.0 host using `open -na "$(pwd)/FluidDynamicsMetalOSX.app" --args --fluid3d-test-failure=reset`; the live process is confirmed with that Debug-only argument. It opens in ordinary 2D Free Play; the argument is armed but **not yet triggered**. Selecting 3D once should display the native safe-recovery alert; after **Continue in 2D**, retry should use the normal successful path. No source or metallib drift was detected, and quick/full evidence validation passed again after the build. The declared PPM captures at steps 0/24/48/72 are present under `.build/fluid3d-evidence/recipe-step-*.ppm`; matching full state dumps are listed above. Manual review was not performed; see the user-directed disposition and unchecked checklist above.

## Evidence index and commands

Machine-readable artifacts: `.build/fluid3d-evidence/{benchmark,projection,advection-boundaries,operators,reset-finite,slice-palette,evolution-visibility,transitions-and-failures,renderer-steps-and-inactivity,regression-matrix}.json`, associated `.log` files, capture files, and test result bundles. `benchmark.json` holds per-source hashes, complete contract/metallib/reference hashes, full sample distributions, resource inventory, and configuration metadata. `regression-matrix.json` holds build/test logs and hashes plus simulator attempt history.

Commands used by this verification include:

```bash
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
python3 -m unittest discover -s Tests/Integration
python3 -m unittest Tests.Integration.test_fluid3d_reference Tests.Integration.test_fluid3d
python3 Tests/Integration/test_fluid3d.py --benchmark
python3 Tests/Integration/test_fluid3d.py --check-evidence --quick
python3 Tests/Integration/test_fluid3d.py --check-evidence
```

The `--quick` checker validates required files, schema, and hashes only; it does not create a new numerical PASS. The full evidence check validates fixture metrics as well. Both checks passed after the report and README update; neither evaluates or replaces manual visual/accessibility/interaction review, which was **NOT PERFORMED**.

## Gap-closure re-verification — 2026-11-22 (G-07-2, G-07-5)

This section re-verifies the final gap-closure sources (plans 07-10, 07-11, 07-14, 07-15, 07-16 and 07-17). Every figure comes from the fresh evidence written by the 2026-11-22 run at commit `1502d69`, or from the 07-10 to 07-17 SUMMARY files. It records UAT observations; requirement acceptance updates belong to `/gsd-verify-work`, and this report does not mark any requirement complete.

- **Run:** started 2026-11-22T07:24:43Z and finished 08:14:09Z. Host: Mac15,6, Apple M3 Pro, arm64; macOS 27.2.1 (26B131); Xcode 27.2 (27B52); Apple Swift 6.4.2; Metal 32023.922; Debug.
- **Reviewed app vs evidence commit:** the user reviewed the app built from `a89f46b` (07-17). The evidence commit `1502d69` adds only the 07-13 validator fix in `Tests/Integration/test_fluid3d.py` (see "Validator fix" below). `Sources/` is identical, and the production metallib SHA-256 is the same in both: `394571a004e383523dee440ec460d2f20ba1f7432f12ded487dda551dd516b91`.

### Final recipe and contract amendments

The shipped `ExperimentRecipes3D.Parameters.lesson` (07-15), as recorded in the fresh `evolution-visibility.json`:
- **Seed speed:** maximum vector speed **0.155**.
- **Blob (B3):** centre (0.64, 0.44, 0.62), radius 0.24, peak 1.
- **Solver settings:** 64³ grid, h = 1/64, dt = 1/60. There is no dye decay and no velocity reseed after reset.

The seed speed was lowered from 0.17 by the user's 2026-11-21 decision. At 0.17, the 1800-step horizon exceeded the E7' projection-input limit (max `dt·||Du*||∞` ≤ 9e-4 with the 1000× reduction rule never active), and no gate or tolerance was relaxed. A finer grid (0.16 / 0.1575 / 0.155) was preregistered as amendment item 9 before any run. 0.155 is the only measured speed that passes both E2 and E7'.

07-15 Stage A speed screen (B2, 1800 steps; quoted from `07-15-SUMMARY.md`):

| Speed | Max input | Ratio to quadratic estimate | Reduction-active steps | Min reduction | Max iterations | Solver-admissible |
|---|---|---|---|---|---|---|
| 0.15 | 6.691e-4 | 0.74 | 0 | none | 136 | yes |
| 0.14 | 5.651e-4 | 0.72 | 0 | none | 133 | yes |
| 0.13 | 4.449e-4 | 0.65 | 0 | none | 131 | yes |
| 0.12 | 3.791e-4 | 0.65 | 0 | none | 129 | yes |

Item-9 extended screen (B3, 1800 steps): 0.16 measured input 9.625e-4 and failed E7'. 0.1575 measured 9.107e-4 and failed E7'. 0.155 measured 7.492e-4 and passed. Between 0.155 and 0.1575 the input rose 22% for a 1.6% change in speed, so Phase 9 speed choices must be measured, not interpolated.

`docs/3d-numerical-contract.md` carries both dated amendments after the preregistered marker:
- the 07-11 **"Human-calibrated early-window visibility amendment"** (gates E1–E7);
- the 07-15 **"Larger-blob, square-root display and 3D lesson-length amendment"**: S1, S2, R1, E7' over 1800 steps, the lesson-length rule, the item-8 seed-speed selection rule, and the item-9 HALT-C record with its finer grid.

### Square-root display transfer (07-14)

The 3D slice displays concentration c through the fixed transfer d = sqrt(clamp(c, 0, 1)). The amber palette stops are unchanged. The middle stop now sits at display value 0.5, which is concentration 0.25.
- **Legend:** "Less dye → More dye · square-root scale". Its axis stays linear in concentration, and its colours follow the shader transfer.
- **Note:** says a square-root brightness scale makes faint dye easier to see.
- **Inspection contract:** `docs/3d-inspection-contract.md` carries the dated square-root amendment.

Fresh `slice-palette.json` (displayTransfer `square-root`; palette invariant at steps 0 and 1):

| Concentration | 0 | 0.015625 | 0.25 | 0.5 | 0.75 | 1 | 1.25 (clamped) |
|---|---|---|---|---|---|---|---|
| sRGB | 0,0,0 | 59,35,9 | 237,139,35 | 244,181,109 | 250,214,166 | 255,241,214 | 255,241,214 |

### Fresh identity

| Item | SHA-256 |
|---|---|
| Preregistered numerical-contract prefix (unchanged) | `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b` |
| Complete numerical contract | `1f396b713eb126c084c71a3cd8465f264f869991db1be23ca6e87bb726aa8aa3` |
| Inspection contract | `ac824cffb3cb3db141cf1c03f9425cd67797db0586246480a258ddd06a502cbb` |
| Production metallib | `394571a004e383523dee440ec460d2f20ba1f7432f12ded487dda551dd516b91` |
| Reference manifest | `3839a295cd2cb53ad97d52747f5960598143a37c9cc9bac65fd75a16d8030ba9` |
| Benchmark reset seed | `ffd6f62cf5d03d0f2a36b32a174015d6e48d13c1e4dc44b1cfec4e3704c6d6c2` |

The source inventories are 24 files (legacy fixture inventory) and 34 files (spatial inventory).

Fresh captures in `.build/fluid3d-evidence/`: `recipe-step-NNN.ppm` at steps 0, 1, 10, 20, 24, 48 and 72, plus every 50 steps from 50 through 1800 (43 PPMs). They sit alongside the `recipe-state-step-*.f32le` state dumps and the manifest `evolution-visibility.json`.

### Early window (fresh `evolution-visibility.json`)

| Step | Slice peak | Samples ≥ 0.02 | Section area ≥ 0.1 | V50 (display L* ≥ 50) | Max L* | RMS from step 0 |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0.712813 | 406 | 331 | 310 | 86.11 | 0 |
| 1 | 0.721830 | 413 | 335 | 317 | 86.48 | 0.002681 |
| 10 | 0.795020 | 460 | 369 | 347 | 89.05 | 0.025118 |
| 20 | 0.854927 | 493 | 400 | 377 | 91.09 | 0.046399 |
| 24 | 0.875415 | 508 | 410 | 388 | 91.74 | 0.053846 |
| 48 | 0.943693 | 568 | 453 | 424 | 93.82 | 0.086792 |
| 72 | 0.937900 | 609 | 479 | 447 | 93.80 | 0.103079 |

- **Step 10:** 188 encoded pixels changed by more than 32 levels (minimum 100), and the RMS from step 0 is 0.025118 (minimum 0.025). E2 binds here, about 0.5% above its threshold.
- **Step 48:** the section area changed by 0.3686 relative to step 0 (minimum 0.3).
- **Result:** `calibratedEarlyWindow.passed` is true.

### Larger blob, fade and return, lesson length

`largerBlobGates.passed` is true:
- **S1:** step-0 section area 331 (minimum 250).
- **S2:** step-0 V50 310 (minimum 300).
- **Fade:** at step **300** (V50 below half its step-0 value).
- **Return:** at step **950**, with V50 165 (minimum 150) and maximum L* 70.50 (minimum 60). This is R1.
- **Derived lesson length:** **1200** steps, from the choices 1200, 1500 and 1800.

1800-step horizon (`threeDLesson`):
- 1800 steps validated; finite throughout.
- No cap hits and no projection failures.
- Maximum iterations 136.
- Maximum input `dt·||Du*||∞` was 7.492403e-4, against the 9e-4 limit (margin 1.201).
- The 1000× reduction rule was active on 0 steps.
- Volume peak was 0.332374 at N = 1200 and 0.215593 at step 1800 (minimum 0.05).
- `shippedLessonSteps` 1200 equals `derivedLessonSteps` 1200.

The capture check (`_validate_evolution_display_captures`, which recomputes V50 and max L* from the PPMs) and `_validate_shipped_lesson_length` both passed inside `run_production_fixture`.

| Step | Slice peak | Section area ≥ 0.1 | V50 | Max L* | Volume peak | Volume mass |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 0.8649 | 491 | 458 | 91.4 | 0.9188 | 4224.8 |
| 200 | 0.3868 | 432 | 371 | 73.4 | 0.8123 | 4149.0 |
| 300 (fade) | 0.2518 | 155 | 92 | 67.0 | 0.6964 | 4108.1 |
| 400 | 0.2421 | 152 | 101 | 66.0 | 0.6029 | 4078.0 |
| 500 | 0.2805 | 154 | 108 | 68.5 | 0.5397 | 4043.1 |
| 600 | 0.3071 | 164 | 123 | 69.8 | 0.4874 | 3998.8 |
| 700 | 0.3215 | 185 | 141 | 70.5 | 0.4421 | 3950.2 |
| 800 | 0.3207 | 203 | 155 | 70.5 | 0.4068 | 3904.8 |
| 900 | 0.3222 | 215 | 163 | 70.5 | 0.3780 | 3868.7 |
| 950 (return) | 0.3234 | 206 | 165 | 70.5 | 0.3690 | 3855.0 |
| 1000 | 0.3286 | 208 | 163 | 70.9 | 0.3604 | 3844.2 |
| 1100 | 0.3343 | 222 | 165 | 71.1 | 0.3487 | 3829.3 |
| 1200 (N) | 0.3291 | 235 | 176 | 70.9 | 0.3324 | 3820.0 |
| 1300 | 0.3064 | 253 | 175 | 69.8 | 0.3096 | 3814.9 |
| 1400 | 0.2667 | 259 | 159 | 67.8 | 0.2879 | 3814.5 |
| 1500 | 0.2340 | 252 | 132 | 64.8 | 0.2702 | 3818.8 |
| 1600 | 0.2111 | 211 | 82 | 62.0 | 0.2538 | 3827.1 |
| 1700 | 0.1981 | 108 | 31 | 60.2 | 0.2363 | 3837.8 |
| 1800 | 0.1767 | 50 | 23 | 57.0 | 0.2156 | 3848.7 |

Over the first 600 steps (`lessonRecipe600`, the 07-11 E7 subset, kept): 600 steps validated, no cap hits or failures, maximum iterations 136, maximum input 6.324226e-4, reduction rule active on 0 steps, volume peak 0.487354 at step 600.

### Shipped 3D lesson length (07-16)

`SimulationState.threeDLessonSteps = 1200` is read through `SimulationMode.lessonStepLimit`. The 3D lesson completes at 1200 steps; the 2D lessons still stop at 600, and Free Play never completes. Gate L1, in both the Swift fixture and the Python validator, keeps the shipped value equal to the evidence-derived one. LES-05's 600-step text is unchanged. The ROADMAP Phase 9 handoff records that Phase 9 planning must reconcile 600 with 1200.

### Benchmark (offscreen, not FPS)

Fresh `benchmark.json`: 60 warm-up advances, then 240 measured advances, at the shipped recipe. It includes the 6571fc5 indirect-dispatch gate, which skips PCG work after convergence.

| Configuration | GPU ms median / p95 / max | Host completion ms median / p95 / max | Host encode ms median / p95 / max | Measured iterations median / p95 / max | Cap hits / failed statuses |
|---|---:|---:|---:|---:|---:|
| Solver only | 15.979 / 18.309 / 19.163 | 27.355 / 46.090 / 48.003 | 3.247 / 6.427 / 7.633 | 33 / 40 / 44 | 0 / 0 |
| Solver + fixed slice | 29.587 / 47.010 / 48.693 | 29.827 / 47.301 / 48.995 | 3.179 / 5.469 / 7.326 | 33 / 40 / 44 | 0 / 0 |

The quality summary's maximum iteration count, including warm-up, is 136. Displayed frame pacing is **NOT MEASURED**; no FPS claim is made.

### Fixes covered

- **G-07-5 (07-10):** the paused 2D canvas now presents after a lesson switch. Covered by a headless spy test and by real-window UI regressions (`testDirectPausedLessonSwitchesRefreshCanvas`).
- **Panel Command-M (07-10):** pressing Command-M in the floating panel minimizes the canvas window (`testPanelKeyMinimizeMinimizesCanvas`).
- **Step button (07-17, found during review):** the Mac Pause button's title change from "Run" to "Resume" shifted Step 25 pt, so a second Step click resumed the lesson. Pause now has a fixed width (`a89f46b`), and `testRepeatedStepClicksAtSamePlaceStayPaused` covers it.

### Validator fix during 07-13

The first 07-13 matrix run (2026-11-21) passed every category and `--check-evidence`, but `--verify-inspection-evidence` failed: `inspection-independence: reset payload bytes`.
- **Cause:** commit `6571fc5` (2026-11-19) added the 48-byte `projection/iteration-gate` buffer to the independent `inspection_inventory()`, but left the reset-payload total pinned at the pre-gate 33,776,184 bytes. The fresh payload was 33,776,232 bytes, and every other resource size was identical.
- **Fix:** with the user's approval, `40c0e70` (RED) and `1502d69` make the total follow the independent inventory instead of a constant.
- **Rerun:** the whole sequence (build, reference, benchmark, matrix, validators) was rerun, because the validator file is hash-pinned.
- **Retained first run:** its logs, result bundles and matrices are under `.build/inspection3d-evidence/logs/07-13-run1-stale-validator/`, `.build/inspection3d-evidence/07-13-run1-stale-validator/` and the `07-13-run1-*.retained.json` files.

### Fresh regression matrix (2026-11-22)

Recorder `.build/07-13-run-matrix.py`. Simulators: iPhone 17 Pro (`8393A81F-69D4-439E-AF8E-ED7665022800`) and iPad Pro 13-inch (M5) (`98C63B09-8AB0-4B26-B9C4-5277D60FCBD5`), both iOS 26.4.

| Check | Result | Duration |
|---|---|---:|
| Mac Debug build | PASS, exit 0 | 3.470 s |
| iOS Simulator Debug build | PASS, exit 0 | 3.780 s |
| Mac state + HUD | PASS, 53/53 (26 state + 27 UI) | 1,374.419 s |
| Full integration | PASS, 50/50 | 970.910 s |
| iPhone HUD | PASS, 11/11 | 282.626 s |
| iPad HUD | PASS, 11/11 | 247.524 s |
| Launchable app (`./build-macos.sh`) | PASS, exit 0 | 4.207 s |

Every category passed on its first attempt; there were no retries in the final run. Attempt wall time totals 2,886.935 s (48.1 min). Logs and xcresult bundles are under `.build/inspection3d-evidence/logs/07-13/` and `.build/inspection3d-evidence/07-13/`. The same attempt records are written to `.build/fluid3d-evidence/regression-matrix.json`, where `manualVisualReview` stays `PENDING`; machine evidence never encodes the human result.

Validators after the run:
- `--check-evidence` passes: "PASS: current production evidence and regression matrix validated. Manual visual review remains PENDING."
- `--verify-inspection-evidence .build/inspection3d-evidence` passes: "PASS: fresh actual inspection evidence and full matrix; human review PENDING; pacing NOT MEASURED."

### User re-observations

**07-12 (2026-11-21), the user, on the app built from `fa35ab9`:**

> "For test 2, I do see the patch fade and come back somewhat, but the brightness as it returns is very low, and so it's hard to interpret what is going on. Part of the problem seems to be that the patch is relatively small to begin with. Another issue is that there are only 500 timesteps, which is barely enough time to see anything happening.
>
> For test 5, all checks now pass.
>
> The Command-M check also passes."

G-07-2 stayed open after 07-12; G-07-5 and Command-M passed.

**07-17 (2026-11-21), the user, on the app built from `a89f46b`:**

The user stopped the first attempt at step 2 with this report:

> "There's a significant problem with executing step 2 - as soon as I hit the "step" button a second time, the steps automatically continue on their own, unless I hit "pause". By that point it's usually at 60 steps or more."

After the fix, the user restarted the review and replied:

> "approved"

As the 07-17 resume signal, that word approves all four G-07-2 sub-findings: (a) returning brightness, (b) starting patch size, (c) run length, and (d) early motion at seed speed 0.155.

### Still not covered

- VoiceOver: **NOT TESTED**.
- Actual macOS 26 runtime: **NOT TESTED**.
- Physical iPhone/iPad multitouch: **NOT TESTED**.
- Displayed frame pacing: **NOT MEASURED**.
- Requirement statuses: unchanged here; `/gsd-verify-work` owns them.

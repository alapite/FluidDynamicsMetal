# Phase 8 — Spatial Inspection Verification

**Scope:** Plan 08-08 automated qualification and handoff, not phase completion.
INS-01, INS-02, INS-03, INS-04 and CTRL-08 remain **PENDING** actual human
visual/accessibility/input review in 08-09. No screenshot, synthetic event,
schema fixture or automated result is human approval.

## Reference environment and freshness

> **Prior run (08-08, 2026-11-15).** The figures in this section and the next are that run's; the current evidence identity is in "Gap-closure re-qualification" at the end of this report.

The real machine-readable evidence namespace is
`.build/inspection3d-evidence/`. `manifest.json` uses separately versioned
`kind: fluid3d-inspection`, schema 1, `evidenceClass: actual-production-run`
and workload `offscreen-spatial-inspection-not-fps`.

The manifest and `regression-matrix.json` record the actual GPU/host model,
OS/build, Xcode, Swift, Metal toolchain, Debug/arm64 configuration, commands,
exit codes, measured wall durations, logs and result bundles. The manifest
holds the complete per-source SHA-256 inventory, freshly built production
metallib path/hash, full numerical contract, pinned inspection contract,
independent Double oracle and each fixture reference-manifest identity.

The fresh run began **2026-11-15T07:29:07Z** on **Mac15,6 / Apple M3 Pro**,
macOS **27.0 (26A428)**, **Xcode 27.2 (27B52)**, Apple Swift **6.4.2**,
Metal **32023.922** (27.2 toolchain), Debug/arm64. The spatial inventory hashes
**34 files**; the legacy fixture inventory remains separately **24 files**.
Independent inspection-oracle SHA-256:
`6fb1e9a948af7fd0bd49131abf8a2292fc12306759f59bd4b9eaf189bb3cf5fc`.
All five fresh inspection reports used production metallib SHA-256
`0481040a6a18d577b2a03385b0bf32de65f71b5f21e2810cc5051e3c36e3aaef`.

- Immutable numerical-prefix SHA-256:
  `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`
- Full amended numerical-contract SHA-256:
  `5fdc33b839d7f135a828ac9e6e3c3b4e7adba03d5341771ddbed4b13767951a8`
- Inspection-contract SHA-256:
  `7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7`

The established 2D solver and Swift/Metal ABI are unchanged. The complete
numerical/inspection contracts remain binding; no tolerance was fitted to
results. The exact production configuration is 64³, dt=1/60, 512 i-fastest
float4 seeds `((i+.5)/8,(j+.5)/8,(k+.5)/8,1)` on an 8³ lattice.

## Automated regression matrix

> **Prior run (08-08).** The fresh 2026-11-22 matrix is in "Gap-closure re-qualification" below.

**Final automated matrix: PASS**, after the separately retained Mac and iPhone
failures/retries below. All commands ran at the final code state; only
documentation and evidence metadata were edited afterward.

| Completed command | Outcome | Wall duration | Evidence |
|---|---|---:|---|
| Exact Mac Debug arm64 build, no overrides | PASS, exit 0 | 4.809 s | `logs/macBuild-attempt-1.log` |
| Exact generic iOS Simulator Debug build, no overrides | PASS, exit 0 | 2.388 s | `logs/iosBuild-attempt-1.log` |
| Full Mac state/HUD, initial attempt | **FAIL**, exit 65; 45/47 passed, 2 failed | 672.312 s | `logs/macTests-attempt-1.log`, `macTests-attempt-1.xcresult` |
| Full Mac state/HUD, unchanged-source retry | PASS, exit 0; **47/47** (25 state + 22 UI), no skips | 402.944 s | `logs/macTests-attempt-2.log`, `macTests-attempt-2.xcresult` |
| Full integration | PASS, exit 0; **45/45** | 1,044.695 s command / 1,044.623 s unittest | `logs/integrationTests-attempt-1.log` |
| iPhone HUD, initial attempt | **FAIL**, exit 65; 9/11 passed, 2 failed | 275.002 s | `logs/iphoneHUD-attempt-1.log`, `iphoneHUD-attempt-1.xcresult` |
| iPhone 17 Pro / iOS 26.4 HUD, full retry after reboot | PASS, exit 0; **11/11**, no skips | 287.356 s | `logs/iphoneHUD-attempt-2.log`, `iphoneHUD-attempt-2.xcresult` |
| iPad Pro 13-inch (M5) / iOS 26.4 HUD | PASS, exit 0; **11/11**, no skips | 252.661 s | `logs/ipadHUD-attempt-1.log`, `ipadHUD-attempt-1.xcresult` |
| Launchable Mac preparation, `./build-macos.sh` | PASS, exit 0 | 8.099 s | `logs/launchableApp-attempt-1.log` |

Paths in this table are relative to `.build/inspection3d-evidence/`. These are
fresh command durations, not clean-build or application frame timings.

The initial Mac attempt failed `testEveryLessonWorkflowAndKeyboardCommands`
when the transport controls disappeared from the accessibility snapshot and
`testMouseDragProducesVisibleDyeAndPausedResizePreservesIt` during a UI-query
timeout. The latter log records unrelated desktop-window interruptions.
No app/test source was changed or assertion relaxed. A bounded full-suite
retry is recorded separately; the initial 45/47 result is not a PASS.
The full unchanged-source Mac retry passed. The initial iPhone attempt on the
discovered iPhone 17 Pro / iOS 26.4 failed the landscape fade adjustment (still
17%) and large-text lesson selector. These match historical simulator
orientation/layout symptoms; that similarity is not proof of cause. Only the
selected simulator was shut down/booted and its boot completion awaited before
the separate full retry. No app/test source changes were made.
The full iPhone retry and first iPad run passed all 11 tests each. Actual
discovered IDs were `8393A81F-69D4-439E-AF8E-ED7665022800` (iPhone) and
`98C63B09-8AB0-4B26-B9C4-5277D60FCBD5` (iPad), both iOS 26.4 build 23E244.
All attempt wall durations, including discovery, failures, retries and app
preparation, sum to **2,950.717 s (49.18 min)**. This is not fast feedback;
operator investigation gaps and schema/documentation work are additional.
The existing iOS `UIScene` lifecycle runtime warning and build-time
UIRequiresFullScreen/AppIntents metadata warnings remain visible in the logs;
passing tests do not remove those advisories.

The actual-evidence CLI exits **0**:
`.build/08-08-evidence-final.log`. It checks the complete fresh bundle, not a
synthetic fixture. Missing required evidence is an error. This full matrix
supplies the final build/test gate after the last code edit.

## Numerical, resource and fixture coverage

These are the required evidence categories, not screenshot-based judgments:

| Fixture | Contract and retained evidence |
|---|---|
| `spatial-slices` | 24 asymmetric samples across XY/XZ/YZ and depths 0/30/50/100%; backside geometry and fixed-plane edge-on projection; 12 cube edges, 1×/2× point scaling, resource reuse and invalid/allocation-failure checks. |
| `inspection-routing` | Presentation-only redraw preserves accepted paused work and fluid bytes; positive image/matrix changes; scoped Reset Camera/Centre Slice, ordinary drain, hidden tracer advance, Restart/reselection and zero-size/depth failure/retry. |
| `tracer-evolution` | Exact 512 full-volume seeds/2,048 lane values; 8,192-byte position storage; 4,096 independent forward-RK2 comparisons across ±XYZ/unequal combined signs, 27 boundary and 28 affine MAC probes; 48 production steps; no feedback and current/prior-failure guards; hidden/nil-drawable scheduling. |
| `tracer-occlusion` | Front/behind black and dyed sheet regions, outside-footprint visibility, opposite-side reversal, discarded disc corners, circular edge-on discs, exact pale-cyan colour and 1×/2× three-point sizing. Black sheet regions remain opaque. |
| `inspection-independence` | Full named reset/traced/queued inventories; 160 negative detector cases; 29 exact paused cases with pending=2; independently scheduled shown/hidden/alternating/nil-drawable comparisons at steps 0/1/24/48; Restart at 0/1; injected failure/recovery outcomes. |

The reset inventory is **37 resources / 33,776,184 payload bytes**: all 32
texture generations, full reduction workspace, both failure latches, tracer
position buffer and retained reset status. Optional tracing adds the full
10,240-byte trace allocation plus its status. Evolved checkpoints retain reset
and latest status (38 resources); queued snapshots retain reset/latest/three
submitted status slots (41 resources). Presentation colour/depth/geometry
allocations are not numerical state. Texture row-padding is not owned voxel
payload. There is no tracer ping/pong/scratch allocation to invent.

The validator independently pins names, shapes, byte counts and formats. It
rejects incomplete inventories, absent per-resource errors, missing failure or
schedule categories, stale identities, missing logs/bundles, relaxed tolerances,
missing mobile matrix entries and legacy benchmark mislabelling.

| Acceptance comparison | Unchanged preregistered gate |
|---|---|
| GPU / independent Double oracle | Finite first; absolute `2e-5 + 2e-4 × abs(reference)` |
| Palette output | ±1 UNORM code |
| Same-device equal-step fluid/tracer resources | Finite first; absolute `2e-6`; exact discrete status/latches |
| Paused resources | Byte-identical, same allocation identity/roles and exact metadata/counters |
| Seeds, lane schema, wall-normal zeros | Exact |
| Pressure | Both timestep-scaled infinity gates `1e-5`, 1000× reduction where specified, cap 320; Phase 7 identity amendments unchanged |

Only process-local allocation addresses and session tokens normalize between
fresh sessions. Paused comparisons retain them exactly. Equal-step schedules
include 0/1/2 extra redraws, wide/tall viewports, backing scales 1/2, zero
viewport/nil drawable and hidden/visible/alternating drawing. These bounded
inspection comparisons do **not** establish Phase 9 all-speed/600-step replay.

### Fresh measured outcomes

All five production inspection fixtures passed in the fresh full integration
run. Durations below include reference preparation, Swift compilation and
production fixture execution, not just GPU commands and never displayed FPS:

| Fixture | Command wall duration | Actual measured result |
|---|---:|---|
| `spatial-slices` | 39.329 s | 24 asymmetric samples; guide pixel area 2×/1× ratio 3.9727965; all required geometry/resource/failure checks passed |
| `inspection-routing` | 50.190 s | All presentation/work preservation, hidden step, Restart/default and depth failure/retry flags passed |
| `tracer-evolution` | 51.131 s | Maximum forward-RK2 oracle error **2.574921e-8**; all 4,096 comparisons and 55 boundary/affine probes passed |
| `tracer-occlusion` | 39.013 s | 1× diameter **2 pixels / 2 points**, 2× diameter **6 pixels / 3 points**, within preregistered raster ±1-point gate; all occlusion checks passed |
| `inspection-independence` | 133.683 s | All 29 paused cases and 160 detector negatives passed; maximum equal-step resource error **0** |

Actual usable drawable reads were **195 shown / 196 hidden / 195 alternating /
0 nil-drawable**. The metadata, inventories, positive presentation changes,
per-resource exact/approximate results and injected failure/recovery records
are embedded in `inspection-independence.json`.

The same full integration command reran established 2D renderer/educational,
bundle/build-setting, independent CPU and all 14 production 3D fixtures.
All seven pressure families converged without cap hits, maximum **317/320**
iterations (only three iterations of stress-case cap margin). Maximum measured
post-projection timestep-scaled divergence was **2.919195e-6**; all independent
residual/divergence/identity checks passed. All-wall normal values remained
exact zero. The 600-step finite soak took **142.395 s**, maximum **144**
iterations; one-step reference, uniform dye and queued-failure checks passed.
This finite soak is regression evidence, not Phase 9 full-lesson acceptance.

Fresh operator errors were **4.250735e-7** (operator), **3.376044e-9**
(divergence operator) and **2.086163e-7** (identity), with zero net wall flux.
These actual results live under `.build/fluid3d-evidence/` in
`{projection,reset-finite,operators,advection-boundaries}.json`; the full suite
log identifies the remaining fixtures and existing 2D checks. The fast
production state/oracle command is separately recorded at
`.build/08-08-focused-final.log`: **2/2 passed**, 7.305 s including compilation.

## Evidence paths and reproduction

All five fixture reports are in
`.build/inspection3d-evidence/{spatial-slices,inspection-routing,tracer-evolution,tracer-occlusion,inspection-independence}.json`.
Each embeds actual execution commands/status/duration and the hash/path of its
production log under `.build/fluid3d-evidence/`. Previous fixture logs are
retained as `*.previous-<timestamp>.log`, never overwritten as an unqualified
retry PASS. Full regression-attempt logs are in
`.build/inspection3d-evidence/logs/`; every XCTest attempt has its own
`.xcresult` and extracted summary JSON. The matrix retains all attempts.

Real offscreen captures include:

- `.build/inspection3d-evidence/cube-default-fit-384x144.ppm`,
  `cube-default-fit-144x384.ppm`, `cube-default-fit-320x240.ppm`,
  `cube-default-fit-2x.ppm` and `cube-increase-contrast.ppm`.
- `.build/inspection3d-evidence/tracer-occlusion-*.ppm` — black/dyed,
  opposite-side, edge-on and 1×/2× fixture images; exact names are recorded in
  `tracer-occlusion.json`.
- Native screenshot attachments are retained in the fresh Mac `.xcresult`.
  Attachments establish captures, not readability/VoiceOver/gesture approval.

After both exact no-override builds from `AGENTS.md`, run:

```sh
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
python3 -m unittest discover -s Tests/Integration
xcrun simctl list devices available
# For a discovered iPhone and iPad, separately:
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=ACTUAL_DISCOVERED_ID' CODE_SIGNING_ALLOWED=NO
python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_inspection_evidence_schema Tests.Integration.test_inspection3d_state
python3 Tests/Integration/test_fluid3d.py --verify-inspection-evidence .build/inspection3d-evidence
./build-macos.sh
```

The checker validates evidence; it does not rerun the matrix or manufacture
missing results. In-memory schema-test fixtures explicitly say
`synthetic-schema-fixture` and are rejected as actual acceptance evidence.
They are never exported as real GPU manifests.

## Prepared human-review handoff — no items pre-approved

The launchable app path is `FluidDynamicsMetalOSX.app` at the repository root,
prepared successfully by `./build-macos.sh`:
`/Users/abiola/Documents/Code/Swift/FluidDynamicsMetal/FluidDynamicsMetalOSX.app`.
Its executable SHA-256 is
`398ec38146ce001cd0b64824a70c410463cf00c56d9c6aa02551292e2ba1476e`;
its metallib hash is the exact fresh production hash recorded above. The
copied app's metallib was independently compared with the fixture manifest.
It is prepared for 08-09, not manually reviewed or pre-approved; no manual
observations or launch/interaction acceptance have been recorded in 08-08.

- [ ] **Initial view/readability:** choose 3D Dye Advection; inspect paused Step
  0, slightly angled amber sheet, subdued cube and X/Y/Z guide, cyan dots and
  readable separate panel. Check Light/Dark, Increase Contrast, Reduce
  Transparency, Bold Text, narrow/tall windows and minimum 320×240 canvas.
- [ ] **Slices and camera:** select all three planes at 0/30/50/100%; confirm
  shared percentage/correct depth-axis text, no auto-facing, both sides and
  legitimate edge-on thinness. Orbit/zoom paused and running; confirm upright
  bounds and guide consistency.
- [ ] **Occlusion/visibility:** check pale-cyan passive dots, hidden markers
  continuing with steps, no reseeding on re-show, no trails or fluid feedback.
  Behind-sheet dots must be hidden even behind black sheet regions; orbit to
  reveal them. Judge actual clarity, not just image-test success.
- [ ] **Reset scopes:** Reset Camera changes only camera; Centre Slice changes
  only shared depth; Restart resets fluid/tracers/pending work to paused Step
  0 while retaining all inspection choices, including hidden tracers.
- [ ] **Keyboard/VoiceOver:** traverse every labelled native control, operate
  plane/depth/camera/visibility and recovery actions; check spoken names,
  units/order, offscreen focus scrolling and focus visibility. Focused Space
  activates only that control; canvas Space toggles transport once; S does
  nothing in 3D. Identifiers and synthetic events do not establish this review.
- [ ] **Physical input/routing:** check actual mouse/trackpad orbit/scroll
  direction and feel; panel-originated drag/scroll must not move camera,
  camera gestures must not inject fluid or activate controls, and guide input
  passes through once. Check inactivity, reactivation and 2D return/input.
- [ ] **Failure/retry:** inspect native Continue in 2D recovery and retry using
  a one-shot Debug fault launch if desired; confirm usable 2D before the
  alert. Record the actual fault and observation rather than assuming success.

| Separate acceptance boundary | Status |
|---|---|
| Phase 8 actual human visual/accessibility/input review | **PENDING — mandatory 08-09 checkpoint** |
| VoiceOver and real mouse/trackpad direction/feel | **NOT TESTED** |
| Actual macOS 26 runtime | **NOT TESTED** — newer macOS host cannot establish it |
| Physical iPhone/iPad multitouch | **NOT TESTED** — simulator HUD is not hardware evidence |
| Displayed FPS/frame pacing | **NOT MEASURED** — offscreen images are not presentation cadence |
| Phase 7 six user-facing requirements/manual checklist | **PENDING**, historical report unchanged |
| Phase 9 speed/teaching/completion/full replay; Phase 10 volume/performance | **OUT OF SCOPE**, no acceptance claim |

Historical Phase 7 solver-only and solver-plus-fixed-slice timings retain their
original labels and date in `3d-phase7-verification.md`; they are not fresh
spatial workload timings and cannot establish FPS or the Phase 10 30-fps floor.

## Gap-closure re-qualification — 2026-11-22

Phase 7 gap closure (plans 07-10 to 07-17) changed hashed spatial sources and both contracts, so the Phase 8 inspection evidence was regenerated end to end. The fresh run started at **2026-11-22T07:25:56Z** at commit `1502d69`. The manifest was generated at 08:14:09Z.

- **Environment:** Mac15,6 / Apple M3 Pro; macOS **27.2.1 (26B131)**; Xcode **27.2 (27B52)**; Apple Swift **6.4.2**; Metal **32023.922**; Debug/arm64.
- **Inventories:** the spatial inventory hashes **34 files**, and the legacy fixture inventory stays separately **24 files**.

| Identity | Prior run (08-08) | Fresh (2026-11-22) |
|---|---|---|
| Production metallib | `0481040a6a18d577b2a03385b0bf32de65f71b5f21e2810cc5051e3c36e3aaef` | `394571a004e383523dee440ec460d2f20ba1f7432f12ded487dda551dd516b91` |
| Numerical-contract prefix | `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b` | unchanged |
| Full numerical contract | `5fdc33b839d7f135a828ac9e6e3c3b4e7adba03d5341771ddbed4b13767951a8` | `1f396b713eb126c084c71a3cd8465f264f869991db1be23ca6e87bb726aa8aa3` |
| Inspection contract | `7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7` | `ac824cffb3cb3db141cf1c03f9425cd67797db0586246480a258ddd06a502cbb` |
| Independent inspection oracle | `6fb1e9a948af7fd0bd49131abf8a2292fc12306759f59bd4b9eaf189bb3cf5fc` | `4cf7a496fc5b7b958160075b68563eb0b83c80e964b8245cdf39e7bd85f28718` |

Gap-closure source changes that entered the spatial inventory:
- `Renderer.swift` and `Sources/macOS/RenderViewController.swift`: the 07-10 paused presentation and panel Command-M, plus the 07-17 fixed-width Pause button.
- `Tests/UI/macOS/HUDUITests.swift`.
- `ExperimentRecipes3D.swift`: the 07-15 recipe, seed speed 0.155 with blob B3.
- `FieldVisualization3D.swift` and `Shaders3D.metal`: the 07-14 square-root transfer and legend.
- `SimulationState.swift`: the 07-16 3D lesson length of 1200.
- The integration test files.
- `docs/3d-inspection-contract.md`, with its dated **square-root display transfer amendment**.

`docs/3d-numerical-contract.md` (the 07-11 and 07-15 amendments) is bound separately through the manifest's `completeContractSHA256`, not through the spatial inventory.

The pressure solver's indirect-dispatch iteration gate (`6571fc5`, 2026-11-19) is also in this inventory. During 07-13 it exposed a stale reset-payload total in the inspection validator, fixed in `40c0e70` and `1502d69`. The first run's failure is retained as `07-13-run1-*`. The 08-09 human reviewer will now see the **square-root palette** on the spatial sheet.

| Command | Outcome | Wall duration | Evidence |
|---|---|---:|---|
| Exact Mac Debug arm64 build | PASS, exit 0 | 3.470 s | `logs/07-13/macBuild-attempt-1.log` |
| Exact generic iOS Simulator build | PASS, exit 0 | 3.780 s | `logs/07-13/iosBuild-attempt-1.log` |
| Full Mac state/HUD | PASS, exit 0; **53/53** (26 state + 27 UI) | 1,374.419 s | `logs/07-13/macTests-attempt-1.log`, `07-13/macTests-attempt-1.xcresult` |
| Full integration | PASS, exit 0; **50/50** | 970.910 s | `logs/07-13/integrationTests-attempt-1.log` |
| iPhone 17 Pro / iOS 26.4 HUD | PASS, exit 0; **11/11** | 282.626 s | `logs/07-13/iphoneHUD-attempt-1.log`, `07-13/iphoneHUD-attempt-1.xcresult` |
| iPad Pro 13-inch (M5) / iOS 26.4 HUD | PASS, exit 0; **11/11** | 247.524 s | `logs/07-13/ipadHUD-attempt-1.log`, `07-13/ipadHUD-attempt-1.xcresult` |
| Launchable Mac preparation | PASS, exit 0 | 4.207 s | `logs/07-13/launchableApp-attempt-1.log` |

Paths are relative to `.build/inspection3d-evidence/`. Every category passed on its first attempt, and attempt wall time totals 2,886.935 s.

`python3 Tests/Integration/test_fluid3d.py --verify-inspection-evidence .build/inspection3d-evidence` passes: "PASS: fresh actual inspection evidence and full matrix; human review PENDING; pacing NOT MEASURED." The 08-08 matrix and manifest are retained as `08-08-regression-matrix.retained.json` and `08-08-manifest.retained.json`.

Unchanged boundaries:
- Every 08-09 human-review checklist item stays unchecked.
- INS-01 to INS-04 and CTRL-08 remain **PENDING**.
- VoiceOver, macOS 26 runtime and physical multitouch remain **NOT TESTED**.
- Displayed frame pacing remains **NOT MEASURED**.

---
phase: 8
slug: spatial-inspection
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-11-13
---

# Phase 8 — Validation Strategy

> Executable validation contract for nine plans / nine waves / seventeen tasks. Approved UI-SPEC is present. `nyquist_compliant: true` records checked **planning coverage**, not human acceptance. Producer outcomes are recorded below and in 08-01 through 08-08 summaries; the mandatory 08-09 actual human review remains pending.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | Existing XCTest state/Mac HUD targets; Python unittest wrappers compiling Swift production fixtures |
| Config | `FluidDynamicsMetal.xcodeproj/xcshareddata/xcschemes/FluidDynamicsMetalOSX.xcscheme`; `Tests/Integration/test_fluid3d.py` source inventory |
| Existing quick run | `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_evidence_schema Tests.Integration.test_fluid3d.Fluid3DTests.test_volume_kernels_read_only_solver_status` |
| New fast oracle (08-01-01 creates it) | `python3 -m unittest Tests.Integration.test_inspection3d_reference` |
| New fast production math/state (08-01-02 creates it; 08-03-01 expands it) | `python3 -m unittest Tests.Integration.test_inspection3d_state` |
| Focused state run | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO -only-testing:FluidDynamicsMetalStateTests` |
| Full integration | `python3 -m unittest discover -s Tests/Integration` after a fresh Mac build |
| Full Mac tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` |
| Measured runtime | 08-08 full integration 45/45 in 1,044.623 s; full Mac final command 402.944 s; all matrix attempts 2,950.717 s total. Full GPU/Xcode feedback is not under 30 s. |

Quick existing tests protect schema/source constraints only; they cannot establish INS-01–04 or CTRL-08. New fast modules provide oracle/math/state feedback; mandatory supplemental production GPU and native UI commands in each plan establish integration. Running only the fast modules does not complete a GPU/UI task. No library/framework installation is needed.

## Sampling Rate

- **After each task:** run the new/changed focused behavioral tests and affected existing checks. Write failing behavior assertions before implementation.
- **After each wave:** build affected app targets, run relevant production fixtures and state/HUD regressions; use the freshly built production metallib.
- **Before phase verification:** both no-override builds, full Mac state/HUD and integration suites, applicable iPhone/iPad HUD regressions; retain separate manual status.
- **Continuity:** every one of the seventeen scheduled tasks has an automated command; all sixteen implementation/documentation tasks have focused feedback plus required integration gates where applicable. The human checkpoint also revalidates evidence, but its observations remain manual.
- **Feedback latency:** target under 30 s for the pure oracle/state command including its compilation; measure and record compilation/run and supplemental GPU/UI times separately in 08-01. Runtime is NOT MEASURED during planning. If the fast command exceeds this target, optimize bounded dependency/fixture reuse without dropping behavioral assertions; do not claim the target was measured or fulfilled from plan review. Historical renderer/GPU tests already exceed 30 s and are explicitly separate required integration gates, not fast-loop commands.

## Per-Task Verification Map

Aliases (each expands to an exact runnable command after the scheduled producer creates it):

- **R:** `python3 -m unittest Tests.Integration.test_inspection3d_reference`
- **S:** `python3 -m unittest Tests.Integration.test_inspection3d_state`
- **G(name):** `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_NAME`, replacing NAME with the literal name in the table. Fresh Mac build required after Metal/source changes.
- **U(name):** `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO -only-testing:FluidDynamicsMetalOSXUITests/HUDUITests/NAME`, replacing NAME with the named case.
- **E:** `python3 Tests/Integration/test_fluid3d.py --verify-inspection-evidence .build/inspection3d-evidence`

Waves 1–7 have execution summaries; Wave 8 schema RED/GREEN is recorded in `08-08-SUMMARY.md`. The fresh full matrix and evidence gate are tracked in `docs/3d-phase8-verification.md`. Wave 9 remains **pending actual human review**. “Create here” in the planning-time availability column identifies the owning producer task, not an absent method today. Supplemental G/U/E gates are mandatory, not alternatives to fast feedback.

| Task ID | Plan / Wave | Requirements | Threat refs / secure behavior | Fast automated feedback | Required supplemental gate | Test availability at planning |
|---|---|---|---|---|---|---|
| 08-01-01 | 01 / 1 | INS-01/02/03/04 | input/oracle: preregistration and independent finite expectations | R | Contract hash/oracle corruption tests within R | Create R here |
| 08-01-02 | 01 / 1 | INS-01/02/04 | input: finite bounded camera and exact operation scopes | S + R | Both app builds | Create S here |
| 08-02-01 | 02 / 2 | INS-01/02/04 | input/queue: ABI, fixed-world read-only sampling | S + R | G(spatial_slices), G(slice_and_palette) | Create spatial_slices here; legacy case exists |
| 08-02-02 | 02 / 2 | INS-01/02/04 | resource: depth reuse/faults and cube transforms | S + R | G(spatial_slices), G(evidence_schema) | Extend spatial fixture here; schema exists |
| 08-03-01 | 03 / 3 | INS-01/02/04 | queue: no pending-step/pause/reset side effects | S | New state_operation_scopes case in S | Extend S here |
| 08-03-02 | 03 / 3 | INS-01/02/04 | resource/queue: no-advance redraw and transactional state | S | G(inspection_routing), G(renderer_steps_and_inactivity), G(transitions_and_failures) | Create routing here; old cases exist |
| 08-04-01 | 04 / 4 | INS-01/02/04, CTRL-08 | routing/access: native focus/keys and scope | S | U(testSpatialInspectionControlsAndKeyboard), U(testSpatialInspectionLayoutAndModeReturn) | Create UI cases here |
| 08-04-02 | 04 / 4 | INS-01/04, CTRL-08 | routing/input: canvas ownership/guide pass-through | S | U(testSpatialInspectionGestureIsolation), previous keyboard case | Create gesture case here |
| 08-05-01 | 05 / 5 | INS-03/04 | resource: deterministic full-volume tracer reset | R + S | G(tracer_evolution) | Create tracer fixture here |
| 08-05-02 | 05 / 5 | INS-03/04 | queue/feedback: production MAC RK2, failure guard, no feedback | R + S | G(tracer_evolution), G(volume_kernels_read_only_solver_status) | Extend oracle/tracer here; source guard exists |
| 08-06-01 | 06 / 6 | INS-03/04 | queue/resource: hidden/nil-drawable advance, rollback/retry | S + R | G(inspection_routing), G(tracer_evolution), G(transitions_and_failures) | Extend earlier fixtures here |
| 08-06-02 | 06 / 6 | INS-01/02/03/04, CTRL-08 | routing/resource: depth-tested discs and checkbox-only visibility | S + R | G(tracer_occlusion), U(testSpatialTracerVisibilityAndRestart) | Create GPU/UI cases here |
| 08-07-01 | 07 / 7 | INS-03/04 | inventory/queue: complete staged data, negative mutation checks | S + R | G(inspection_independence) | Create complete-inventory fixture here |
| 08-07-02 | 07 / 7 | INS-03/04, CTRL-08 | routing/queue: complete paused/equal-step invariance | S + R | G(inspection_independence), G(inspection_routing), G(renderer_steps_and_inactivity) | Extend independence fixture here |
| 08-08-01 | 08 / 8 | All five | evidence: fail-closed freshness/coverage schema | G(inspection_evidence_schema), G(evidence_schema) | Negative manifest mutations in schema test | Create new schema here; existing schema needs no GPU |
| 08-08-02 | 08 / 8 | All five | evidence/coverage: real regression results, honest statuses | G(inspection_evidence_schema) + S | E; both builds/full Mac/full integration/iPhone+iPad HUD | E created by previous task; matrix infrastructure exists |
| 08-09-01 | 09 / 9 | All five | coverage: explicit actual human observations | E | Blocking human review; identifiers/images do not replace it | E from 08-08; human review pending |

Task dependencies are explicit in PLAN frontmatter; each producer runs before its consumers. No dangling `<automated>MISSING</automated>` reference exists: tests are created test-first within their owning task or earlier waves. Threat IDs match PLAN registers and represent mitigations to verify, not confirmed exploit findings.

## Preregistered Acceptance Protocol

1. Preserve existing `docs/3d-numerical-contract.md` thresholds, 320 pressure cap, 64³ production grid, all-generation finite checks and exact wall-normal zeros. Never modify its immutable prefix for inspection work.
2. Freeze the new inspection contract before assessing results. Record plane mappings XY `(s,t,d)`, XZ `(s,d,t)`, YZ `(d,t,s)` if adopted, depth `d=pct/100`, cell-centred clamped sampling, camera matrix convention, forward tracer RK2 and exact seed distribution.
3. Verify planes at 0/30/50/100%, known asymmetric affine dye/landmarks, front/back and edge-on views. Central XY must interpolate cell planes 31/32 equally. GPU-oracle fields use `2e-5 + 2e-4*abs(reference)`; palette output uses ±1 UNORM code. Reject nonfinite values first.
4. Verify opaque-sheet occlusion with front/back markers across black and dyed regions, outside the sheet footprint and after opposite-side orbit; a changed view must not reorient the sheet.
5. Tracer fixtures cover deterministic full-volume reset, independent Double forward RK2 for ±X/Y/Z and unequal combined velocities, MAC staggered sampling and all wall/edge/corner handling. No force/dye feedback. GPU-oracle tolerance uses item 3; same-device equal-step tracer tolerance is absolute `2e-6` world units, proposed before measurements.
6. Complete inventory includes both generations of all diagnostic textures, transported velocities, pressure high/low and scratch, reduction workspace, retained status, simulation/session failure latches, every tracer position/scratch buffer, configuration and discrete step/generation metadata. Inventory names and sizes must match; unexposed resources require diagnostic read-only access, not silent omission.
7. Paused rendering/inspection/resize batches require **byte-for-byte unchanged** evolution resource snapshots and exact counters/latches. Separate equal-step paired runs at 0/1/24/48 use absolute `2e-6` float-field/tracer tolerance, finite-first checks and exact discrete state/wall zeros. Exercise hidden/visible/alternating tracers, no drawable, multiple redraws, all planes/depths and viewport sizes; retain positive image/matrix changes to prove controls really worked.
8. Restart preserves camera/plane/shared depth/visibility while resetting all fluid/tracer state, step/pending input and pause state. Inject tracer/pipeline/depth/reset failures and delayed completions; retain usable 2D recovery. This extension does not establish Phase 9 speed/completion/full-repeatability acceptance.

## Wave 0 Requirements

- [x] `08-UI-SPEC.md` approved and read; manual planning UI gate satisfied without override.
- [x] 08-01-01: independent `inspection3d_reference.swift` / `test_inspection3d_reference.py` and contract.
- [x] 08-01-02: production `test_inspection3d_state.swift` / `.py`, shared values/math and Xcode membership.
- [x] 08-02-01: spatial fixture registration/ABI assertions and all three standalone source lists, at first camera-dependent compile (not deferred until Renderer integration).
- [x] 08-03-01/02: state-scope and no-advance renderer routing assertions.
- [x] 08-04-01/02: native keyboard/focus/gesture/guide and negative side-effect UI cases — `08-04-SUMMARY.md`; actual VoiceOver/physical feel remains untested.
- [x] 08-05-01/02: tracer reset/RK2/guard/no-feedback production fixture and independent expected positions — `08-05-SUMMARY.md`.
- [x] 08-06-01/02: hidden/nil-drawable schedule, occlusion and native tracer/restart/failure cases — `08-06-SUMMARY.md`.
- [x] 08-07-01/02: complete staging/inventory including workspace/status/latches/tracers plus negative detector checks and paired runs — `08-07-SUMMARY.md`.
- [x] 08-08-01: separate Phase8 evidence schema/CLI and negative manifests — observed RED/GREEN, `.build/08-08-task1-red-assertion.log` and `.build/08-08-task1-green.log`; synthetic schema validity is not an actual GPU run.
- [x] All17 tasks have automated feedback plus assigned feature-specific integration gates; every producer/dependency is scheduled and numerical/2D regression gates are preserved.

No framework installation is proposed. Do not create passing-only test stubs or mark absent methods as runnable verification.

## Build and Regression Gates

```sh
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
python3 -m unittest discover -s Tests/Integration
```

Run the full Mac test command above. Discover available simulator IDs with `xcrun simctl list devices available` for applicable iPhone/iPad HUD checks; do not hardcode an assumed available device ID. Preserve historical Phase 7 evidence and label fresh Phase 8 evidence separately, especially the old solver-only/fixed-slice benchmark workload.

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Instructions |
|---|---|---|---|
| Readable modest three-quarter view, subdued guides, cyan/amber distinction | INS-01/02/03 | Numeric pixels do not establish usability | Inspect Light/Dark, minimum canvas, narrow/tall windows, edge-on/backside and zoom bounds |
| VoiceOver names/order and real keyboard operation | CTRL-08 | Accessibility identifiers alone do not establish spoken output/focus quality | Traverse and operate all inspection controls with keyboard/VoiceOver; confirm Space only activates focused control or canvas transport once |
| Pointer/trackpad feel and exclusive routing | CTRL-08 | Synthetic events do not fully qualify hardware gesture behavior | Orbit/zoom paused/running; drag/scroll panel without camera movement; confirm 2D drag still injects only where intended |

Phase 7 unperformed manual review remains pending. Actual macOS 26 runtime and physical mobile multitouch remain **NOT TESTED**; displayed frame pacing remains **NOT MEASURED**. Do not substitute later Phase 10 performance acceptance or infer a human PASS from automation.

## Validation Sign-Off

- [x] Executable plans exist with assigned per-task verification and waves
- [x] Every task has automated verification and explicit creation-before-use ordering
- [x] Sampling continuity checked against final plans: 17/17 automated entries; no unverified three-task window
- [x] Every absent test reference has an owning producer task; no passing-only scaffolds
- [x] No watch-mode flags proposed
- [x] Focused feedback latency measured and acceptable — 08-01 summary records final four-test fast command 2.955 s including compilation; full matrix/GPU/XCTest latency is separate, not promised under 30 s.
- [x] `nyquist_compliant: true` records checked executable plan contract, not implementation success

**Approval:** Planning contract approved 2026-11-13 after distinct inline review. Producer execution is now documented separately above; this does not rewrite planning as implementation evidence. All five Phase 8 requirements remain pending mandatory 08-09 human acceptance. No human review was performed by plan-phase or inferred from automation.

## 08-08 Fresh Automated Gate — 2026-11-15

- [x] Both exact no-override Debug builds: Mac arm64 and generic iOS Simulator.
- [x] Full Mac 47/47 (25 state + 22 HUD); initial 45/47 failure and full unchanged-source retry retained.
- [x] Full integration 45/45, including all 14 production 3D fixtures and established 2D/GPU/educational/bundle checks.
- [x] Discovered iPhone 17 Pro and iPad Pro 13-inch (M5), both iOS 26.4: full HUD 11/11 each. Initial iPhone 9/11, reboot and full retry retained.
- [x] New/legacy schema tests and focused schema/state command; actual evidence CLI exits 0.
- [x] Launchable root Mac app prepared; copied metallib matches actual GPU evidence.
- [x] Distinct inline review against 08-08 original plan; not independent-agent verification.
- [ ] Actual 08-09 human visual/accessibility/input review — mandatory and not auto-approved.

Evidence: `.build/inspection3d-evidence/{manifest,regression-matrix}.json`,
all attempt logs/xcresults in that namespace, `.build/08-08-evidence-final.log`,
and `docs/3d-phase8-verification.md`. `wave_0_complete: true` now records genuinely
produced/tested harness infrastructure, not phase acceptance. Actual macOS 26,
physical multitouch and VoiceOver/real input feel remain NOT TESTED; displayed
frame pacing remains NOT MEASURED. Phase 7 historical/pending claims are unchanged.

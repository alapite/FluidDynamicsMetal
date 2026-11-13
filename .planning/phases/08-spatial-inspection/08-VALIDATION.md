---
phase: 8
slug: spatial-inspection
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-11-13
---

# Phase 8 — Validation Strategy

> Draft validation contract derived from `08-RESEARCH.md`. Executable plans are not yet created: the manual UI-SPEC gate is pending. Proposed new test methods below do not exist yet. No implementation or runtime verification is claimed.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | Existing XCTest state/Mac HUD targets; Python unittest wrappers compiling Swift production fixtures |
| Config | `FluidDynamicsMetal.xcodeproj/xcshareddata/xcschemes/FluidDynamicsMetalOSX.xcscheme`; `Tests/Integration/test_fluid3d.py` source inventory |
| Existing quick run | `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_evidence_schema Tests.Integration.test_fluid3d.Fluid3DTests.test_volume_kernels_read_only_solver_status` |
| Focused state run | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO -only-testing:FluidDynamicsMetalStateTests` |
| Full integration | `python3 -m unittest discover -s Tests/Integration` after a fresh Mac build |
| Full Mac tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` |
| Estimated runtime | NOT MEASURED for Phase 8. Historical full integration: 572 s; do not promise full GPU/Xcode feedback under 30 s. |

Quick existing tests protect schema/source constraints only; they cannot establish INS-01–04 or CTRL-08. Final planning must add feature-specific automated feedback and populate task IDs/waves below without inventing results.

## Sampling Rate

- **After each task:** run the new/changed focused behavioral tests and affected existing checks. Write failing behavior assertions before implementation.
- **After each wave:** build affected app targets, run relevant production fixtures and state/HUD regressions; use the freshly built production metallib.
- **Before phase verification:** both no-override builds, full Mac state/HUD and integration suites, applicable iPhone/iPad HUD regressions; retain separate manual status.
- **Continuity:** no three consecutive tasks without automated feedback. Final planner/checker must verify this against actual tasks.
- **Feedback latency:** measure and record focused CPU/state and GPU times separately during execution; target a fast pure-state/math subset instead of treating long full-suite latency as compliant by assertion.

## Per-Task Verification Map

Task IDs/plans/waves are **unassigned pending UI-SPEC and executable planning**. These are requirement-level verification obligations, not fake scheduled tasks.

| Requirement | Threat Ref | Secure behavior | Test type | Automated command / status |
|---|---|---|---|---|
| INS-01 | T-08-input | Bounded finite camera, outside-volume zoom, reset-only changes | State/math + production render + Mac HUD | New state/HUD assertions and proposed `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_spatial_slices` — MISSING |
| INS-02 | T-08-input | Validated plane/depth; correct axes/endpoints/midpoint | GPU + independent analytic fixture | Proposed `Fluid3DTests.test_spatial_slices` — MISSING |
| INS-03 | T-08-queue | Status-guarded, step-only passive advancement even hidden | GPU + independent RK2 reference | Proposed `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_tracer_evolution` — MISSING |
| INS-04 | T-08-resource, T-08-queue | Complete-state independence, reset retention and safe fallback | Production renderer/readback + state | Proposed `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_inspection_independence` — MISSING |
| CTRL-08 | T-08-routing | Focus and exclusive canvas/panel routing; no injection | Mac HUD + production contact/state assertions | New native keyboard/gesture cases — MISSING; command to finalize with actual case names |

Threat IDs are draft references for later PLAN threat-model blocks: input = nonfinite/unbounded uniforms; resource = unchecked allocations/resize churn; queue = failed/stale/in-flight work; routing = cross-window input effects. They are not findings of confirmed exploits.

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

- [ ] `08-UI-SPEC.md` — required before manual plan-phase proceeds (or explicit operator `--skip-ui` override).
- [ ] Pure inspection/camera tests and shared state representation; align Xcode test membership.
- [ ] Production spatial-slice/occlusion, tracer and complete-state fixtures registered in Swift/Python with independent expected results.
- [ ] Diagnostic readback inventories include workspace/status/latches and new tracer buffers; existing `scanSimulation` does not compare workspace values.
- [ ] New shared dependencies added to standalone source lists in `test_fluid3d.py`, `test_renderer_correctness.py`, `test_educational_release.py` and source-hash inventories.
- [ ] Native focus/keyboard and panel-versus-canvas gesture tests, including negative side-effect assertions.
- [ ] Final plans assign every task an automated command or explicit dependency on these checks and preserve existing numerical/2D regression commands.

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

- [ ] Executable plans exist with assigned per-task verification and waves
- [ ] Every task has automated verification or an explicit Wave 0 dependency
- [ ] Sampling continuity checked against final plans
- [ ] Every MISSING test reference is scheduled
- [x] No watch-mode flags proposed
- [ ] Focused feedback latency measured and acceptable
- [ ] `nyquist_compliant: true` set only after the executable plan contract is checked

**Approval:** Pending. Research/strategy artifacts only; UI gate prevents claiming Phase 8 planned or plan verification passed.

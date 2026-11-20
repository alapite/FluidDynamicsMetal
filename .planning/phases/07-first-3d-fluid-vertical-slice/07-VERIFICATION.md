---
phase: 07-first-3d-fluid-vertical-slice
verified: 2026-11-20T00:00:00Z
status: human_needed
score: 4/4 must-haves verified
covered_files:
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-01-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-01-SUMMARY.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-02-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-02-SUMMARY.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-03-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-03-SUMMARY.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-04-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-04-SUMMARY.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-05-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-05-SUMMARY.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-06-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-06-SUMMARY.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-07-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-07-SUMMARY.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-08-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-08-SUMMARY.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-09-PLAN.md
  - .planning/phases/07-first-3d-fluid-vertical-slice/07-09-SUMMARY.md
  - Sources/Shared/ExperimentRecipes3D.swift
  - Sources/Shared/FieldVisualization3D.swift
  - Sources/Shared/FluidSimulation3D.swift
  - Sources/Shared/PressureProjection3D.swift
  - Sources/Shared/Renderer.swift
  - Sources/Shared/Shaders3D.metal
  - Sources/Shared/SimulationState.swift
  - Sources/macOS/RenderViewController.swift
  - Tests/Integration/test_fluid3d.py
  - Tests/Integration/test_fluid3d.swift
  - Tests/UI/macOS/HUDUITests.swift
  - Tests/Unit/SimulationStateTests.swift
  - docs/3d-numerical-contract.md
  - docs/3d-phase7-verification.md
covered_digest: "v4:sha256:cbd393bd9c7b0bcbf03247d340791ef0bc684b89ad828f30468eb822d7dc9634"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "In the running Mac app, open the Simulation menu and the toolbar/selector; choose 3D Dye Advection."
    expected: "A non-selectable '3D' group lists '3D Dye Advection' separately from the 2D modes; 2D titles and Command-1..4 are unchanged; selecting it enters the lesson."
    why_human: "Native AppKit appearance, menu grouping and selection feedback are visual; only XCUITest structure checks exist (no human review has been performed, and the 07-09 checkpoint was closed by user direction, not by observation)."
  - test: "Observe the fixed slice at step 0 and after Run for several seconds / after several Steps."
    expected: "A nonblank amber dye slice (X right, Y up, Z=0.5) that visibly changes shape over steps; the learner can read it as a tumbling volume rather than a flat 2D animation."
    why_human: "'Looks like a genuine evolving 3D fluid' is a perceptual judgement. Production-GPU numerical evidence (depth variation, Z-travel, nonplanar reference) exists but screenshots/metrics do not establish visual character."
  - test: "Run, Pause, Resume and Step on the 3D lesson; watch the step counter."
    expected: "Entry is paused at 'Step 0'; Run/Pause/Resume update the counter; each paused Step advances exactly one."
    why_human: "Counter visibility/legibility and control feel in the real window. Logic is covered by state tests and production-renderer fixtures."
  - test: "While running and while manually paused, switch to another app / minimize, wait, then return."
    expected: "Counter frozen while inactive; no burst of catch-up steps on return; a manually paused lesson stays paused."
    why_human: "Real window-server activation/deactivation (willResignActive/didBecomeActive, miniaturize) is not exercised by the controlled-callback fixture. macOS 26 runtime is NOT TESTED."
  - test: "Switch from 3D back to Free Play and each 2D lesson (also trigger the injected 3D failure path if available)."
    expected: "Established 2D selection/reset defaults, no stale mouse/touch input, native recovery message and retry work."
    why_human: "Native alert/recovery UX and real pointer input cannot be driven by the fixtures."
  - test: "Keyboard-only traversal and VoiceOver pass over the 3D panel (Phase 8 controls now share the panel)."
    expected: "Labelled controls, logical focus order, readable panel contrast; panel copy matches or is formally superseded by the Phase 8 UI contract."
    why_human: "Accessibility and focus order are not machine-verified (07-UI-REVIEW is code-only, 14/24, with Phase 8 supersessions)."
---

# Phase 7: First 3D Fluid Vertical Slice Verification Report

**Phase Goal:** Users can select a genuine evolving 3D fluid on Mac, inspect its initial behaviour through a basic slice, and control its advancement with numerical evidence supporting the result.
**Verified:** 2026-11-20
**Status:** human_needed
**Re-verification:** No, initial verification (no prior VERIFICATION.md existed)

Verified against the code as it is now (HEAD 6fb2f5e; source identical to 8740038), which includes Phase 8 inspection work and the 2026-11-20 solver performance changes (iteration gate, warm start, fused PCG, two-deep frame pipelining). SUMMARY claims were not relied on; the key fixtures were re-run here against a fresh Metal library.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Mac user can select the 3D dye-advection lesson and see a nonblank fixed slice of a 64³ volume whose depth-varying velocity transports dye nonplanarly; production GPU evidence distinguishes it from an extruded 2D simulation | ✓ VERIFIED (automated); visual confirmation is a human item | `SimulationMode.dyeAdvection3D` + `macModes` (SimulationState.swift); Mac selector/menu append "3D" group (RenderViewController.swift:314,489). `FluidSimulation3D.encodeStep` advects all three velocity components, projects, advects dye (not an extruded 2D path). Re-run `evolution-visibility` PASS: depth variation 0.1059 (0.882 of reset speed), u/v/w each change 0.16-0.23 of reset speed, dye-seeded production probes travel up to 3.24 cells in Z over 72 steps, full-volume unequal-axis dye moved 5.79 cells in Z (CPU reference 5.79), analytic curved reference plane-RMS/arc 0.0166 vs 0.01 minimum, step-48 slice RMS vs step 0 0.0524 vs 0.005 minimum. `slice-palette` fixture covers midpoint z=0.5 (planes 31/32) nonblank production image. |
| 2 | Entry paused at step 0; Run/Pause/Resume updates visible counter; each paused Step advances exactly once | ✓ VERIFIED (automated) | `selectMode` for 3D sets `userPaused = true`, `beginReset` zeroes `stepCount`; `requestSingleStep/consumeStep` bound pending steps. Mac state tests (25 tests, run here: 0 failures) include `testThreeDEntryAndExactQueuedSteps`, `testThreeDReselectAndRestartResetPausedTransport`. Re-run `renderer-steps-and-inactivity` PASS (real production Renderer, nil-drawable/paused-redraw steps). Visual counter legibility is a human item. |
| 3 | Inactivity freezes evolution and reactivation introduces no catch-up steps; switching back to 2D restores established selection/reset behaviour without stale input | ✓ VERIFIED (automated) | `Renderer.resignActive` drains in-flight 3D work, clears pending steps and input; `shouldAdvance` requires `!inactive`; macOS observers wired (RenderViewController.swift:149-150,263-272). `testThreeDInactivityPreservesManualIntent`, `testThreeDReturnPreservesTwoDPreferences` pass; re-run `renderer-steps-and-inactivity` and `transitions-and-failures` (rollback/retry/return to all four 2D modes) PASS. Real window-server deactivation is not exercised (human item; macOS 26 NOT TESTED). |
| 4 | Production encoder passes documented three-axis advection, compatible projection, all-six-face boundary and finite-value fixtures; references and tolerances defined before acceptance; both pressure residual and post-projection divergence measured | ✓ VERIFIED with warnings (see below) | Contract `docs/3d-numerical-contract.md` is hash-pinned and precedes kernels (07-01). Re-run here, fresh metallib: quick CPU contract OK; GPU `projection`, `advection-boundaries`, `evolution-visibility`, `transitions-and-failures`, `renderer-steps-and-inactivity` PASS on current code. Step loop checks `trueResidualDTInf <= 1e-5`, `projectedDivergenceDTInf <= 1e-5`, identity error and wall-normal zero for every step (600-step soak; max 317/320 iterations in the stress fixture). One-step production `encodeStep` is compared elementwise against the independent CPU reference for u/v/w/dye. The orchestrator additionally reports the full integration suite (45 tests) green. |

**Score:** 4/4 truths verified; 0 present-but-behavior-unverified. Six user-facing requirements still need human observation (below), so overall status is `human_needed`.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Sources/Shared/FluidSimulation3D.swift` | 64³ velocity+dye step | ✓ VERIFIED | Substantive 317 lines; `encodeStep` transports u/v/w and dye, calls projection; wired from Renderer |
| `Sources/Shared/PressureProjection3D.swift` | Matrix-free PCG projection with status | ✓ VERIFIED | 1418 lines; status slot carries residual/divergence diagnostics; called by `encodeStep` |
| `Sources/Shared/Shaders3D.metal` | 3D kernels | ✓ VERIFIED | Guarded advection/projection/slice kernels present and exercised |
| `Sources/Shared/ExperimentRecipes3D.swift` | Deterministic curl-of-potential initial state | ✓ VERIFIED | Wall-closed, depth-varying 3-component field + off-centre dye blob |
| `Sources/Shared/SimulationState.swift` | 3D mode, paused entry, step accounting | ✓ VERIFIED | `dyeAdvection3D`, `macModes`, `selectMode`, `consumeStep` |
| `Sources/Shared/Renderer.swift` | Transactional 3D transition, step/inactivity handling | ✓ VERIFIED | `transitionTo3D` rollback to usable 2D; step gated by `shouldAdvance`/`canStep` |
| `Sources/macOS/RenderViewController.swift` | Selector, menu, transport, panel | ✓ VERIFIED (structure) | Grouped 2D/3D navigation; appearance needs human review |
| `docs/3d-numerical-contract.md`, `docs/3d-phase7-verification.md` | Preregistered contract, evidence report | ⚠️ PARTIAL | Exist and hash-pinned, but see warnings (zero-guess wording, stale source inventory) |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| Mac selector/menu | `Renderer.selectMode` -> `transitionTo3D` | `.dyeAdvection3D` | WIRED |
| `Renderer.draw` | `FluidSimulation3D.encodeStep` + tracer advance | `state.shouldAdvance || canStep && pendingSteps>0`, then `consumeStep` | WIRED |
| `Renderer.resignActive/becomeActive` | `SimulationState` + MTKView pause | NSApplication will-resign / did-become-active observers | WIRED |
| `encodeStep` | `PressureProjection3D.encodeProjection` -> status slot | residual/divergence diagnostics | WIRED |
| 3D failure | `restoreUsableTwoDState` | `failActiveThreeDSession` | WIRED |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real data | Status |
|----------|------|--------|-----------|--------|
| Slice render | dye texture | `fluid3DAdvectDyeGuarded` output from projected u/v/w | Yes (production readback fixtures) | ✓ FLOWING |
| Step counter | `state.stepCount` | `consumeStep` once per encoded step | Yes | ✓ FLOWING |

### Behavioral Spot-Checks (run here)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| CPU contract | `unittest ...ReferenceContractTests.test_quick_contract` | OK | PASS |
| Projection gates, production | `unittest ...Fluid3DTests.test_projection` | PASS (with renderer test, 112 s) | PASS |
| Renderer steps/inactivity | `unittest ...test_renderer_steps_and_inactivity` | PASS | PASS |
| Evolution/nonplanarity, advection/boundaries, transitions | `unittest ...test_evolution_and_visibility test_advection_and_boundaries test_transitions_and_failures` | 3 tests OK (152 s) | PASS |
| Mac state tests | `xcodebuild test ... -only-testing:FluidDynamicsMetalStateTests` | 25 tests, 0 failures | PASS |
| Evidence bundle freshness | `python3 Tests/Integration/test_fluid3d.py --check-evidence --quick` | FAIL (source-hash staleness; see warnings) | WARNING |

Not re-run here: Mac HUD UI tests (orchestrator reports 48 Mac scheme tests passed on 8740038), iOS HUD tests (not rerun this session; iOS stays 2D-only), full integration suite (orchestrator: 45 OK).

### Probe Execution

SKIPPED: the phase declares no `probe-*.sh` scripts.

### Requirements Coverage

All seven IDs in ROADMAP, REQUIREMENTS.md and the PLAN frontmatter reconcile; none orphaned. Code/automated evidence exists for every ID; for the six user-facing IDs, REQUIREMENTS.md correctly still records "Pending - manual review not performed", and this verification does not count automated evidence as human acceptance.

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| SIM-04 | 07-05, 06, 07, 08, 09 | Select 3D lesson from Mac app | ✓ SATISFIED (automated) / ? NEEDS HUMAN | Mode + selector/menu wiring; Mac HUD navigation tests |
| SIM-05 | 07-01 to 07-04, 06, 08, 09 | Genuine 64³ evolving dye, depth-varying, nonplanar | ✓ SATISFIED (automated) / ? NEEDS HUMAN (visual) | Evolution fixture numbers above |
| SIM-06 | 07-05, 06, 07, 08, 09 | Return to 2D with established behaviour, no stale input | ✓ SATISFIED (automated) / ? NEEDS HUMAN | State test, transitions fixture |
| LES-01 | 07-05, 06, 07, 08, 09 | Paused at step 0, Run/Pause/Resume, visible count | ✓ SATISFIED (automated) / ? NEEDS HUMAN | State + renderer fixtures |
| LES-02 | 07-05, 06, 07, 08, 09 | Exactly one step per Step action | ✓ SATISFIED (automated) / ? NEEDS HUMAN | `testThreeDEntryAndExactQueuedSteps`, renderer fixture |
| LES-06 | 07-05, 06, 07, 08, 09 | Inactivity freezes, no catch-up | ✓ SATISFIED (automated) / ? NEEDS HUMAN | Inactivity state test + controlled production renderer fixture |
| VER-03 | 07-01 to 07-04, 06, 08, 09 | Production-kernel numerical checks vs documented fixtures/tolerances | ✓ SATISFIED | Fixtures re-run on current code (warnings apply) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (phase source files) | - | TBD/FIXME/XXX scan | None found | No unreferenced debt markers in the checked 3D sources, Renderer, SimulationState, RenderViewController or test_fluid3d |
| `Sources/Shared/PressureProjection3D.swift` | 207, 472-481, 1250-1293 | Unreachable `gatingIteration` branches after fusion (07-REVIEW WR-03) | Warning | Dead code, no goal impact |
| Several | - | Code-review warnings WR-01..WR-05 and 12 info items, dispositions all "open" | Warning | See below |

### Warnings (non-blocking, recorded for the developer)

1. **Contract describes a solver that no longer ships (07-REVIEW WR-01, confirmed).** `docs/3d-numerical-contract.md:54` still says `q=0` initial guess; production now warm-starts from the previous step's pressure and gates PCG on internal stop targets. Acceptance gates (1e-5 residual/divergence, 320 cap) are unchanged and are still met by the fixtures I re-ran, but only step 1 is compared elementwise to the independent oracle, so the warm-start path has no independent-reference equivalence test and no dated amendment. This weakens, but does not defeat, "references and tolerances defined before acceptance".
2. **Advection oracle fixtures exercise sibling kernels, not the shipped ones (WR-02, confirmed).** `fluid3DAdvectVelocity`/`fluid3DAdvectDye` and `encodeAdvection` are used only by `Tests/Integration/test_fluid3d.swift:4469,6098`; the app runs `*Guarded` variants. The guarded kernels call the same `backtraceRK2` and `sampleLattice` helpers and the production `encodeStep` is independently checked against the CPU reference for one asymmetric step and by the 72-step recipe and 600-step gates, so criterion 4 is met, but the eleven three-axis/six-face advection cases do not literally validate the production kernel bodies. Recommend routing them through `encodeStep`.
3. **Evidence bundle is stale against current source.** `--check-evidence --quick` fails with stale source/metallib hashes (benchmark, storage-abi, operators, reset-finite, spatial-slices, slice-palette, inspection-routing, tracer-*, inspection-independence) and an unexpected source inventory. The committed `docs/3d-phase7-verification.md` is dated 2026-11-08 with a 21-file inventory that predates the Phase 8 and performance commits. During this verification I regenerated five untracked `.build/fluid3d-evidence` JSONs (projection, advection-boundaries, evolution-visibility, transitions-and-failures, renderer-steps-and-inactivity); `.build` is not git-tracked. Refresh by rerunning the full `python3 Tests/Integration/test_fluid3d.py` and regenerate the report. The 2026-11-08 performance baseline in that report also predates the solver speed-ups and is not a Phase 10 qualification.
4. **UI contract drift.** 07-UI-REVIEW scores 14/24 (code-only); several deviations are Phase 8 supersessions that still need a formal Phase 8 UI-SPEC addendum, and "Preparing 3D lesson..." status copy is absent.
5. **Not tested:** macOS 26 runtime, physical-device multitouch, iOS HUD tests this session, displayed frame pacing.

### Human Verification Required

See the `human_verification` list in the frontmatter (six items): native selector/menu, visual character of the fixed slice, Run/Pause/Step counter, real app deactivation/minimize, 2D return and failure recovery, keyboard/VoiceOver. The 07-09 manual review was never performed; the user directed documentation closeout on an assumption of no issues, which is not an observation and is not counted here.

### Gaps Summary

No blocking gaps. Every roadmap success criterion is backed by code present in the current tree and by production-kernel or production-renderer tests that pass on the current source (re-run here). The phase is `human_needed` rather than `passed` because the six user-facing requirements (SIM-04, SIM-05, SIM-06, LES-01, LES-02, LES-06) rest on visual, native-interaction and real-activation behaviour that only a person can confirm, and that review has not happened. VER-03 is satisfied by automated evidence, with warnings 1-3 as recommended follow-up (contract amendment, advection fixtures through the production kernels, evidence refresh).

---

_Verified: 2026-11-20_
_Verifier: Claude (gsd-verifier)_

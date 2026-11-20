---
phase: 07-first-3d-fluid-vertical-slice
plan: 11
subsystem: simulation-3d-recipe-calibration
tags: [metal, 3d-fluid, recipe-calibration, preregistered-gates, evidence-validator, uat-gap-closure]

requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: production 3D solver, fixed-slice renderer, evolution-visibility fixture, numerical contract
provides:
  - Dated human-calibrated early-window visibility amendment (E1-E7), recipe envelope and Phase 9 solver-cliff constraint appended after the preregistered marker
  - ExperimentRecipes3D.Parameters with the calibrated lesson recipe (speed 0.17, centre (0.66, 0.44, 0.59), radius 0.17)
  - evolution-visibility fixture with steps 10/20, section-area and encoded-change metrics and a 600-step lesson-recipe check
  - Fail-closed Python validation of the amendment gates, recipe envelope and 600-step check
affects: [09-repeatable-3d-advection-lesson, 07-12, 07-13]

plan_head_before: f80ce2a2ff3faf5a67d3618ec6d40a4f415f4f51
plan_head_after: 80c5e34d2402dc9174a31ce9f995faee2287a98b

actuals:
  tokens: 13300
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Gates are committed and shown RED on the unchanged recipe before any recipe value changes (preregistration by commit order)"
    - "Candidate recipes are scored by the largest minimum normalized margin across E2-E7 with every log retained"
    - "Fixture computes every metric before evaluating gates and throws one assertion carrying the full metric JSON"

key-files:
  created: []
  modified:
    - docs/3d-numerical-contract.md
    - Sources/Shared/ExperimentRecipes3D.swift
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py

key-decisions:
  - "Phase 9 solver-cliff constraint (affects 09-repeatable-3d-advection-lesson): projection input divergence scales roughly with speed squared and crosses 1e-3 near x1.62 of the original 0.12 seed (about 0.194). Measured minimum 1000x-rule reductions were 1026x at x1.75, 1007x at x2.25 and 995.3x at x3, where the run hard-failed at step 164 with a finalAcceptanceFailed latch, then at least 1372x from x3.5. Any Phase 9 speed must stay outside the x1.6-x3.3 band or add in-solver PCG margin (for example continue to at least 1500x when input >= 1e-3); the rule is never relaxed. The shipped speed 0.17 has max input 7.61e-4 and never activates the rule."
  - "Shipped lesson recipe is speed 0.17, centre (0.66, 0.44, 0.59), radius 0.17 (candidate C4), chosen over speed-0.18 candidates because the seed-speed-bound input-divergence margin (9e-4 / max input) rose from 1.055 to 1.183 while the weakest visibility gate (E2) stayed at 1.215."
  - "Amendment gates are additive and dated after END PREREGISTERED CONTRACT; the prefix SHA-256 a7768571... is unchanged and no tolerance (1e-5, 1000x, cap 320, 1e-10, 2e-5+2e-4) was touched."
  - "The opaque single-slice depth limit is inherent to the sheet and remains Phase 10 (volume view) scope; this plan makes the Phase 7 slice readable, it does not add depth cues."

requirements-completed: [SIM-05, VER-03]

coverage:
  - id: D1
    description: "Dated human-calibrated early-window visibility amendment (E1-E7, recipe envelope, Phase 9 cliff record) appended after the marker; prefix hash unchanged"
    requirement: "SIM-05"
    verification:
      - kind: unit
        ref: "python3 -m unittest Tests.Integration.test_fluid3d_reference.ReferenceContractTests.test_quick_contract"
        status: pass
    human_judgment: false
  - id: D2
    description: "Calibrated lesson recipe passes every preregistered and amendment gate and the 600-step lesson check on the production solver"
    requirement: "SIM-05"
    verification:
      - kind: integration
        ref: "python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_evolution_and_visibility"
        status: pass
    human_judgment: true
    rationale: "Numeric gates calibrate but do not establish human readability of early motion; 07-12 re-observation is the blocking human checkpoint"
  - id: D3
    description: "Fail-closed evolution-visibility evidence validation of the amendment gates, envelope and 600-step lesson check"
    requirement: "VER-03"
    verification:
      - kind: unit
        ref: "Tests/Integration/test_fluid3d.py#test_evolution_visibility_evidence_requires_calibrated_window_and_600_step_lesson"
        status: pass
      - kind: unit
        ref: "Tests/Integration/test_fluid3d.py#test_evidence_schema"
        status: pass
    human_judgment: false
  - id: D4
    description: "Solver, shaders and projection tolerances unchanged; both app targets build with the new recipe"
    requirement: "VER-03"
    verification:
      - kind: other
        ref: "git diff --exit-code 4de6352 -- Sources/Shared/Shaders3D.metal Sources/Shared/FluidSimulation3D.swift Sources/Shared/PressureProjection3D.swift"
        status: pass
      - kind: other
        ref: "xcodebuild Mac and iOS Simulator no-override builds (AGENTS.md)"
        status: pass
    human_judgment: false

duration: 17min
completed: 2026-11-20
status: complete
---

# Phase 7 Plan 11: Human-Calibrated 3D Lesson Recipe Summary

**Preregistered human-calibrated early-window gates (shown failing on the old recipe first), then a faster-flow, larger, off-equator blob (speed 0.17, centre (0.66, 0.44, 0.59), radius 0.17) that visibly changes the fixed slice by step 10 and passes a 600-step production check, guarded by a fail-closed Python evidence validator and an unchanged solver.**

## Performance

- **Duration:** 17 min (candidate GPU runs about 97 s each)
- **Started:** 2026-11-20T23:09:03Z
- **Completed:** 2026-11-20T23:28Z
- **Tasks:** 2 (4 production commits: RED/GREEN each)
- **Files modified:** 4

## Accomplishments

- Amendment "Human-calibrated early-window visibility amendment — 2026-11-20 (UAT G-07-2)" appended after the marker with calibration source, gates E1-E7, recipe envelope, the unchanged-tolerance statement and the Phase 9 solver-cliff record. `test_quick_contract` still passes, so the prefix hash `a7768571...` is unchanged.
- `ExperimentRecipes3D.Parameters` and `lesson` (with the four old static names kept as read-only aliases) route `initialState(for:parameters:)`; the fixture reads every recipe value from `ExperimentRecipes3D.lesson` and the hard-coded `0.42, 0.48, 0.52` literals are gone.
- `evolution-visibility` now observes steps 0/1/10/20/24/48/72 with `sliceAreaAtLeast0_1`, emits `calibratedEarlyWindow` and `lessonRecipe600` (600 production steps with checkpoint scans and `recipe-step-100..600.ppm` captures), and throws one assertion with all failed gates plus the full metric JSON.
- Python validator recomputes every amendment threshold (never trusting `passed`), cross-checks RMS/area/peak against observations, pins the gate constants and enforces the recipe envelope; a 27-mutation negative test proves it fails closed.

## RED on the original recipe (speed 0.12, radius 0.12, centre (0.42, 0.48, 0.52))

Fresh Mac build, then the quick contract passed and `test_evolution_and_visibility` failed on the planned assertion (`RED_EVIDENCE_OK`, `target_test_failed`). Failing gates:

| Gate | Observed | Threshold |
|---|---:|---:|
| E2 step-10 slice RMS from step 0 | 0.01286 | >= 0.025 |
| E3 step-20 slice RMS from step 0 | 0.02485 | >= 0.04 |
| E4 step-10 encoded-change samples (>= 32/255) | 41 | >= 100 |
| E5 step-48 section-area relative change | 0.0325 (123 -> 119) | >= 0.30 |

E1 (peak0 0.964), E6 (peaks 0.93/0.89/0.88/0.81, areas 123/122/123/119) and E7 (600 steps, max input 3.79e-4, max 129 iterations, volume peak 0.233 at step 600) already passed. Log: `.build/fluid3d-evidence/recipe-candidates/ORIGINAL-RED.log`.

## Candidate table

All candidates inside the envelope, all passing every gate. Margin = observed/threshold for minimums and threshold/observed for maximums. Logs and JSON: `.build/fluid3d-evidence/recipe-candidates/{ID}.log|.json|.params` (final confirming run is `FINAL-C4.*`).

| ID | speed | centre | r | rms10 (E2) | rms20 (E3) | enc10 (E4) | A0 / relA48 (E5) | min peak / min area (E6) | max input (E7) | vol peak @600 | min margin (binding) |
|---|---:|---|---:|---:|---:|---:|---|---|---:|---:|---|
| C1 | 0.18 | (0.68, 0.44, 0.58) | 0.16 | 0.0314 (1.257) | 0.0524 (1.310) | 149 (1.49) | 147 / 0.578 (1.47 / 1.93) | 0.837 / 188 (2.79 / 3.76) | 8.53e-4 (1.055) | 0.214 (4.29) | 1.055 (E7 input) |
| C2 | 0.18 | (0.62, 0.44, 0.58) | 0.18 | 0.0259 (1.038) | 0.0454 (1.134) | 144 (1.44) | 206 / 0.408 (2.06 / 1.36) | 0.864 / 239 (2.88 / 4.78) | 8.53e-4 (1.055) | 0.265 (5.30) | 1.038 (E2) |
| C3 | 0.18 | (0.66, 0.44, 0.59) | 0.17 | 0.0319 (1.277) | 0.0548 (1.371) | 164 (1.64) | 156 / 0.647 (1.56 / 2.16) | 0.805 / 195 (2.68 / 3.90) | 8.53e-4 (1.055) | 0.242 (4.84) | 1.055 (E7 input) |
| **C4 (shipped)** | 0.17 | (0.66, 0.44, 0.59) | 0.17 | 0.0304 (1.215) | 0.0527 (1.317) | 160 (1.60) | 156 / 0.647 (1.56 / 2.16) | 0.799 / 193 (2.67 / 3.86) | 7.61e-4 (1.183) | 0.253 (5.05) | **1.183** (E7 input) |
| C5 | 0.17 | (0.68, 0.44, 0.58) | 0.16 | 0.0299 (1.198) | 0.0505 (1.263) | 143 (1.43) | 147 / 0.571 (1.47 / 1.91) | 0.832 / 185 (2.77 / 3.70) | 7.61e-4 (1.183) | 0.223 (4.46) | 1.183 (E7 input) |

C1-C3 are the plan's debug-session start placements at speed 0.18; C4 and C5 were added (within the five extra allowed) because input divergence depends only on seed speed and bound every 0.18 candidate at 1.055. C4 and C5 tie at 1.183; C4 wins on the next-smallest margin (E2 1.215 against 1.198). Only five of the maximum eight candidates were needed; the halt rule never applied.

## Shipped recipe, gate values and margins (final GREEN run)

`Parameters.lesson`: maximumVectorSpeed 0.17, blobCenter (0.66, 0.44, 0.59), blobRadius 0.17, blobPeak 1. Envelope check: |cz-0.5|/r = 0.529 in [0.30, 0.60]; all coordinates in [0.30, 0.70].

- E1 step-0 slice peak 0.671 (>= 0.5, margin 1.34)
- E2 step-10 RMS 0.03037 (>= 0.025, 1.215); E3 step-20 RMS 0.05267 (>= 0.04, 1.317)
- E4 step-10 encoded-change samples 160 (>= 100, 1.60)
- E5 A(0) = 156, A(48) = 257, relative change 0.647 (>= 0.30, 2.16)
- E6 peaks 0.799/0.878/0.900/0.905 and areas 193/224/231/257 at steps 10/20/24/48
- Original preregistered gates still pass: step-24 RMS 0.0594, step-48 RMS 0.078, step-72 0.072.

## 600-step lesson statistics (E7)

600 of 600 steps accepted, 0 projection failures, 0 cap hits, max 144 PCG iterations (cap 320), max input dt*||Du*||inf 7.608e-4 (limit 9e-4), 0 reduction-gate-active steps (minimum reduction not applicable), all fields finite, volume dye peak 0.2527 at step 600 (>= 0.05).

| Step | slice peak | area >= 0.1 | count >= 0.02 | volume peak | volume mass |
|---:|---:|---:|---:|---:|---:|
| 100 | 0.456 | 214 | 354 | 0.803 | 1492.2 |
| 200 | 0.053 | 0 | 73 | 0.582 | 1463.6 |
| 300 | 0.095 | 0 | 166 | 0.437 | 1451.4 |
| 400 | 0.147 | 45 | 221 | 0.355 | 1444.1 |
| 500 | 0.184 | 69 | 261 | 0.295 | 1432.5 |
| 600 | 0.201 | 90 | 293 | 0.253 | 1414.9 |

The dye mostly leaves the Z=0.5 plane around steps 200-300 and returns later (reported, not gated, per amendment E7 and D-09). The 3D panel note (D-13) already says "dye can move out of the plane" and "There is no explicit dye fading", so no copy change was needed.

## Task Commits

1. **Task 1 (tracer, TDD): preregister gates, show RED, recalibrate**
   - RED `8c6678a` (test): amendment, parameterization with unchanged values, extended fixture; failed on the original recipe
   - GREEN `17b0164` (feat): calibrated `lesson` recipe (C4)
2. **Task 2 (TDD): fail-closed evidence validation**
   - RED `566cbfa` (test): synthetic report plus 27 mutations and 3 omitted keys; all 30 subtests failed on the planned assertion (`RED_EVIDENCE_OK`)
   - GREEN `80c5e34` (feat): constants and validator extension

**Plan metadata:** see the docs commits that follow this summary.

## Files Created/Modified

- `docs/3d-numerical-contract.md` - amendment appended after the marker
- `Sources/Shared/ExperimentRecipes3D.swift` - `Parameters`, calibrated `lesson`, parameterized `initialState`
- `Tests/Integration/test_fluid3d.swift` - lesson-driven evolution-visibility with steps 10/20, E1-E7 and `lessonRecipe600`
- `Tests/Integration/test_fluid3d.py` - gate constants, `_validate_evolution_calibration`, synthetic report and negative test

## Decisions Made

See `key-decisions`. In addition: steps 1-72 keep the original throw-immediately per-step gates; steps 73-600 are accounted (`projectionFailures`, `capHits`, `stepsValidated`) so a failing candidate still reports every metric, and the loop stops at the first failure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Default argument `.lesson` did not compile**
- **Found during:** Task 1 (first Mac build)
- **Issue:** The target API wrote `parameters: Parameters = .lesson`, but `lesson` lives on `ExperimentRecipes3D`, not on `Parameters`, so Swift reported "type 'ExperimentRecipes3D.Parameters' has no member 'lesson'".
- **Fix:** Default argument is `ExperimentRecipes3D.lesson`; the public shape (`lesson`, `initialState(for:parameters:)`, aliases) is as specified.
- **Files modified:** `Sources/Shared/ExperimentRecipes3D.swift`
- **Verification:** Mac and iOS Simulator builds pass.
- **Committed in:** `8c6678a`

**2. [Rule 2 - Missing Critical] Gate failure reporting made independent of the original requires**
- **Found during:** Task 1 (fixture design)
- **Issue:** The plan requires every metric be computed before any gate, but the original `require` lines for steps 0/24/48 sat before the new metrics and would hide them on failure.
- **Fix:** Moved the original (unchanged) requires after the amendment block and added E1 to the amendment failure list, so a failing candidate always prints the full metric JSON.
- **Files modified:** `Tests/Integration/test_fluid3d.swift`
- **Committed in:** `8c6678a`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing critical). **Impact on plan:** none on scope; both are mechanical.

Other process notes (not deviations): the Task 2 RED test first hit a `NameError` (an INVALID_RED setup fault) because the synthetic report referenced a production constant; it now carries its own literal gate values, which also keeps the test independent of the code under test. Commits are on `master` as directed for sequential mode, so the protected-branch assertion in the commit guard was not applied.

## TDD Gate Compliance

Task 1: `test(07-11)` `8c6678a` precedes `feat(07-11)` `17b0164`. The RED commit also carries the amendment and the behaviour-neutral parameterization (plan Steps A-C commit together as the RED commit by design, before any recipe value changed). Task 2: `test(07-11)` `566cbfa` precedes `feat(07-11)` `80c5e34`. No REFACTOR commits.

## Issues Encountered

- A full Mac UI suite was not run (not part of this plan); the known host Finder-window click hang is therefore not exercised.
- `--check-evidence` freshness is expected to be stale now (hashed sources and the complete contract changed); 07-13 regenerates it. Not edited to hide staleness.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface; the only new files are retained local evidence under ignored `.build/`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 07-12 (blocking human re-observation) can now judge the faster, off-equator lesson; the numeric gates here do not claim human acceptance, so SIM-05 stays pending (the shared-ID gate also withheld SIM-05 and VER-03 because 07-12 and 07-13 declare them).
- 07-13 must regenerate the full evidence bundle (recipe, contract hash and hashed sources changed).
- The opaque single-slice depth limit remains Phase 10 scope; the solver-cliff constraint for Phase 9 is recorded in the amendment and in STATE.md.

---
*Phase: 07-first-3d-fluid-vertical-slice*
*Completed: 2026-11-20*

## Self-Check: PASSED

Created/modified files and all four commits (`8c6678a`, `17b0164`, `566cbfa`, `80c5e34`) verified present; all candidate logs and the final evidence JSON exist under `.build/fluid3d-evidence/`.

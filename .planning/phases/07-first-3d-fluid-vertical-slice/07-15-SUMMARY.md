---
phase: 07-first-3d-fluid-vertical-slice
plan: 15
subsystem: 3d-lesson-recipe
tags: [swift, numerical-contract, recipe-calibration, e7-prime, uat-gap, g-07-2, tdd]

requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: 07-14 square-root display transfer; 07-12 user report (returning dye dim, patch small, run too short); 07-15 first-execution halt (speed 0.17 fails E7' over 1800 steps)
provides:
  - Contract amendment items 1-8 (larger-blob S1/S2, return R1, 3D lesson length, E7' over 1800 steps, seed-speed selection rule) and item 9 (HALT-C record, finer speed grid)
  - Shipped 3D lesson recipe at seed speed 0.155, blob B3 (centre 0.64/0.44/0.62, radius 0.24, peak 1)
  - Derived 3D lesson length 1200 steps, measured at the shipped speed (input to 07-16)
  - Fail-closed Python validation of largerBlobGates, threeDLesson, the recomputed lesson length and the display captures
affects: [07-16, 07-17, 07-13, phase-09-speed-choices]

actuals:
  tasks: 3
  commits: 5

plan_head_before: 845b678beaea020bfd3279f0cb326667add1b4a8
commits: 5

tech-stack:
  added: []
  patterns:
    - "Preregister in a dated contract amendment, commit, and only then run candidates"
    - "Validator recomputes derived values (lesson length, V50, max L*) from raw checkpoints and captures instead of trusting emitted ones"

key-files:
  created:
    - .planning/phases/07-first-3d-fluid-vertical-slice/07-15-SUMMARY.md
  modified:
    - docs/3d-numerical-contract.md
    - Tests/Integration/test_inspection3d_reference.py
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
    - Sources/Shared/ExperimentRecipes3D.swift

key-decisions:
  - "Seed speed 0.155 (was 0.17): the only measured speed where E2 and E7' both pass. 0.1575 and 0.16 exceed the E7' input limit; 0.15 and below miss E2."
  - "Peak 1.25 is void on the unchanged solver (reset dye must be in 0...1); no candidate used a peak other than 1."
  - "Finer grid 0.16/0.1575/0.155 added by user decision after HALT-C, preregistered as amendment item 9 before any run."

duration: approximately 3 h across three executions (two halts)
completed: 2026-11-21
---

# Phase 7 Plan 15: Lower 3D seed speed and larger blob — Summary

**The 3D lesson now ships at seed speed 0.155 with the larger B3 blob. Every preregistered gate passes over the full 1800-step horizon, the 1000x reduction rule is never active, and the derived lesson length is 1200 steps.**

## Performance

- Three executions: the first halted at Task 1 (speed 0.17 fails E7'). The second committed Task 1, then halted at HALT-C in Task 2. The third, run directly by the orchestrator at the user's request, preregistered the finer grid and finished Tasks 2 and 3.
- 13 candidate runs plus 1 FINAL, about 3 minutes each.

## Accomplishments

- **Task 1 (`ef30a0b`):** preregistered contract amendment items 1-8 and repinned `PHASE7_HASH`. The 1800-step harness reproduced the expected RED on the 07-11 recipe, matching `0715-RED.log` on every label and solver value.
- **HALT-C (second execution):** every speed from 0.15 down to 0.12 passes the solver side of E7', but no candidate passed E2. The best was B3 at 0.15, at a margin of 0.974. The peak-1.25 batch could not run, because `FluidSimulation3D` rejects reset dye outside 0...1.
- **Item 9 (`cefdc4f`):** the user chose finer speeds between 0.15 and 0.17. Item 9 records HALT-C, voids the peak-1.25 batches and preregisters B3 at 0.16, 0.1575 and 0.155, with B1, B2 and B4 as a fallback at the best admissible speed. The solver, the gates and the tolerances are unchanged. It was committed before any run at those speeds.
- **Task 2 (`a35e5fa`):** B3 at 0.155 passed every gate. 0.16 and 0.1575 failed E7' on input divergence. The selection set had one member, so the fallback batch did not run. FINAL reproduced the winner on every field.
- **Task 3 (`7bb548c` RED, `97d9752` GREEN):**
  - The validator now requires the largerBlobGates and threeDLesson contracts.
  - It recomputes fadeStep, returnStep, R1 and derivedLessonSteps from the checkpoints.
  - It recomputes V50 and the maximum L* from every capture PPM.
  - The fixture runner now asserts the capture check.

## Stage A speed screen (B2, 1800 steps; item 8)

| Speed | Max input | Ratio to quadratic estimate | Reduction-active steps | Min reduction | Max iterations | Solver-admissible |
|---|---|---|---|---|---|---|
| 0.15 | 6.691e-4 | 0.74 | 0 | none | 136 | yes |
| 0.14 | 5.651e-4 | 0.72 | 0 | none | 133 | yes |
| 0.13 | 4.449e-4 | 0.65 | 0 | none | 131 | yes |
| 0.12 | 3.791e-4 | 0.65 | 0 | none | 129 | yes |

## Item 9 extended screen (B3, 1800 steps)

| Speed | Max input | Reduction-active steps | Max iterations | E2 margin | E7' margin | Verdict |
|---|---|---|---|---|---|---|
| 0.16 | 9.625e-4 | 0 | 140 | 1.035 | 0.935 | FAIL (E7' input) |
| 0.1575 | 9.107e-4 | 0 | 137 | 1.020 | 0.988 | FAIL (E7' input) |
| 0.155 | 7.492e-4 | 0 | 136 | 1.005 | 1.201 | PASS |

Between 0.155 and 0.1575 the input rises steeply, by 22% for a 1.6% change in speed. That is much faster than the roughly s^4.4 trend fitted over 0.15-0.17. Phase 9 speed choices must be measured, not interpolated.

## Full candidate table

All rows are from `.build/fluid3d-evidence/recipe-candidates/0715-candidates.tsv`. Blob centres are (0.66, 0.44, z) for B1 and B2, and (0.64, 0.44, 0.62) for B3 and B4.

| ID | Speed | Blob | Peak | Exit | Min margin | Binding gate | Fade / return / derived |
|---|---|---|---|---|---|---|---|
| A015 | 0.15 | B2 | 1 | 1 | 0.936 | E2 | 250 / 850 / 1200 |
| A014 | 0.14 | B2 | 1 | 1 | 0.878 | E2 | 300 / 950 / 1200 |
| A013 | 0.13 | B2 | 1 | 1 | 0.819 | E2 | 300 / 950 / 1200 |
| A012 | 0.12 | B2 | 1 | 1 | 0.760 | E2 | 350 / 950 / 1200 |
| B1-015-P100 | 0.15 | B1 | 1 | 1 | 0.950 | E2 | 250 / none / none |
| B3-015-P100 | 0.15 | B3 | 1 | 1 | 0.974 | E2 | 300 / 1000 / 1200 |
| B4-015-P100 | 0.15 | B4 | 1 | 1 | 0.835 | E5 | 350 / 400 / 1200 |
| B3-015-P125 | 0.15 | B3 | 1.25 | 1 | no metrics | reset dye rejected | n/a |
| B1-015-P125 | 0.15 | B1 | 1.25 | 1 | no metrics | reset dye rejected | n/a |
| B3-0160-P100 | 0.16 | B3 | 1 | 1 | 0.935 | E7' | 300 / 850 / 1200 |
| B3-0158-P100 | 0.1575 | B3 | 1 | 1 | 0.988 | E7' | 300 / 800 / 1200 |
| B3-0155-P100 | 0.155 | B3 | 1 | 0 | 1.005 | E2 | 300 / 950 / 1200 |
| FINAL | 0.155 | B3 | 1 | 0 | 1.005 | E2 | 300 / 950 / 1200 |

## Selection under items 8-9

The selection set is every exited-0 run, which here is only B3-0155-P100. It is therefore the winner, and Stage B'' was not needed. FINAL reproduced the winner exactly: S1 331, S2 310, fade 300, return 950, derived 1200, 1800 steps, 136 iterations, input 7.492403e-4, and every margin identical.

**For 07-16:**
- selected speed **0.155**
- derived lesson length **1200 steps**
- return at step 950 (V50 165, maximum L* 70.5)
- volume peak at step 1200 is 0.332

## Gate margins of the shipped recipe

| Gate | E2 | E3 | E4 | E5 | E6 | S1 | S2 | R1 | E7' |
|---|---|---|---|---|---|---|---|---|---|
| Margin | 1.005 | 1.160 | 1.880 | 1.229 | 2.650 | 1.324 | 1.033 | 1.100 | 1.201 |

E2, the step-10 slice RMS, binds at about 0.5% above its threshold. The shipped recipe passes, but any later change to the solver, dt or slice sampling that reduces early motion even slightly will trip E2. That would be a correct, fail-closed signal.

## Task Commits

1. `ef30a0b` test(07-15): preregister larger-blob/lesson-length gates and seed-speed selection (RED on 07-11 recipe)
2. `cefdc4f` docs(07-15): preregister finer seed-speed grid 0.16/0.1575/0.155 (amendment item 9)
3. `a35e5fa` feat(07-15): ship 3D lesson recipe at seed speed 0.155 with larger blob B3
4. `7bb548c` test(07-15): require larger-blob S1/S2/R1, 1800-step lesson and display-capture evidence (RED)
5. `97d9752` test(07-15): validate larger-blob gates, 1800-step lesson and display captures fail-closed (GREEN)

## Decisions Made

- The speed is 0.155, chosen by the user-approved item-9 extension. No gate, tolerance or solver line was relaxed.
- Peak 1.25 is void. The envelope text in item 6 and `LESSON_RECIPE_ENVELOPE` still allow a peak up to 1.25, but no recipe can use it without a solver change.

## Deviations from Plan

- **The speed grid was extended after HALT-C,** by user decision, through dated amendment item 9 (committed before any run). Accordingly, the Task 2 verify command's speed whitelist was checked against the extended grid.
- **Task 3 synthetic report:** the shared 07-11 synthetic passing report's step-0 section area moved from 156 to 260 (and step 48 to 360) so that it satisfies S1. The "section-area change" mutation moved to 290 accordingly, and it still fails for its original reason.
- **The capture check is asserted in `run_production_fixture`** directly after the evidence JSON is written, because that function has no separate metric-validation step.
- **The third execution ran inline in the orchestrator session,** at the user's request, instead of through a GSD executor.

## Issues Encountered

- The protected-branch guard blocked the second execution's first commit. The user set `git.allow_default_branch_commits: true`.

## Threat Flags

None. The edits are confined to test, contract and recipe; there are no new inputs or I/O beyond reading local PPM evidence.

## Human review

These are numeric gates, not human acceptance. Plan 07-17 remains the blocking human checkpoint.

## Next Phase Readiness

07-16 can set the 3D lesson length to 1200 steps at speed 0.155.

## Self-Check: PASSED

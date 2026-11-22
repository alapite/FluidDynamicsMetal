---
phase: 07-first-3d-fluid-vertical-slice
plan: 13
subsystem: verification-evidence
tags: [regression-matrix, evidence, d-17, d-09, verification-report, uat-gap, g-07-2, g-07-5]

requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: 07-12 (G-07-5 user PASS) and 07-17 (G-07-2 user approval, g07_2_outcome approved)
provides:
  - Fresh validator-accepted Phase 7 and Phase 8 evidence for the final gap-closure sources
  - Dated sections "Gap-closure re-verification — 2026-11-22" and "Gap-closure re-qualification — 2026-11-22"
  - Inspection validator reset-payload total derived from the independent inventory
affects: [phase-07-verification, 08-09, phase-09]

actuals:
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Derive validator totals from the independent expected layout instead of pinning a number"

key-files:
  created:
    - .planning/phases/07-first-3d-fluid-vertical-slice/07-13-SUMMARY.md
  modified:
    - Tests/Integration/test_fluid3d.py
    - docs/3d-phase7-verification.md
    - docs/3d-phase8-verification.md

key-decisions:
  - "The stale reset-payload pin (33776184, before 6571fc5's 48-byte iteration-gate buffer) was fixed by user decision (option 1), test first, and the whole evidence sequence was rerun."

duration: approximately 2 h of machine time across two matrix runs
completed: 2026-11-22
---

# Phase 7 Plan 13: Fresh regression matrix and verification reports — Summary

**All seven matrix categories passed on their first attempt at `1502d69`, and both fail-closed validators accept the fresh evidence. Both verification reports have dated gap-closure sections.**

## Approval gate (Task 1 step 0)

The gate ran before any build and exited 0. The five values were:
- g07_2_outcome approved
- g07_2_a_returning_brightness approved
- g07_2_b_patch_size approved
- g07_2_c_run_length approved
- g07_2_d_early_motion approved

The commit check (`git diff --quiet a89f46b -- Sources Tests docs`) also exited 0 before the first run.

## Reviewed commit vs evidence commit

- **Reviewed:** `a89f46b`, from `.build/07-17-review-app.json`.
- **Evidence:** `1502d69` adds only the 07-13 validator fix in `Tests/Integration/test_fluid3d.py`. `Sources/` is identical, and both use metallib `394571a0…6b91`.

## Matrix (second run, 2026-11-22T07:24:43Z – 08:14:09Z)

| Category | Result | Duration | Count |
|---|---|---:|---|
| macBuild | PASS | 3.470 s | n/a |
| iosBuild | PASS | 3.780 s | n/a |
| macTests | PASS | 1,374.419 s | 53/53 (26 state + 27 UI) |
| integrationTests | PASS | 970.910 s | 50/50 |
| iphoneHUD (iPhone 17 Pro, iOS 26.4) | PASS | 282.626 s | 11/11 |
| ipadHUD (iPad Pro 13-inch M5, iOS 26.4) | PASS | 247.524 s | 11/11 |
| launchableApp | PASS | 4.207 s | n/a |

- Total attempt time: 2,886.935 s.
- Steps run before the matrix: the Mac build, `--export --check-contract` (prefix `a7768571…` unchanged, reference manifest `3839a295…`) and `--benchmark`. All exited 0.

**First run (2026-11-21):** all seven categories passed, and `--check-evidence` passed. `--verify-inspection-evidence` failed with `inspection-independence: reset payload bytes`.
- **Cause:** fresh payload 33,776,232 bytes against a pin of 33,776,184. Commit `6571fc5` added the 48-byte `projection/iteration-gate` buffer to `inspection_inventory()` but left the total pinned.
- **Decision:** the user chose option 1.
- **Fix:** `40c0e70` (RED) adds `test_inspection_reset_payload_total_follows_independent_inventory`. `1502d69` makes the validator and its synthetic fixture sum the independent inventory. The expected layout itself is unchanged.
- **Retained:** the first run's artifacts are kept as `07-13-run1-*`.

## Validators

- `--check-evidence`: "PASS: current production evidence and regression matrix validated. Manual visual review remains PENDING."
- `--verify-inspection-evidence .build/inspection3d-evidence`: "PASS: fresh actual inspection evidence and full matrix; human review PENDING; pacing NOT MEASURED."
- After the report edits, `--check-evidence --quick` and `--verify-inspection-evidence` still pass.

## Key fresh values

**Hashes:**
- complete contract `1f396b71…a8aa3`
- inspection contract `ac824cff…2cbb` (08-08: `7f793d4e…e0c7`)
- metallib `394571a0…6b91`
- oracle `4cf7a496…8718`
- benchmark seed `ffd6f62c…d6c2`

**Evolution evidence:**
- calibratedEarlyWindow passed, with step-10 RMS 0.025118 (E2 binding) and 188 encoded changes.
- largerBlobGates passed: S1 331, S2 310, fade 300, return 950 (V50 165, L* 70.50).
- threeDLesson: 1800 steps validated, max input 7.4924e-4, 136 iterations, reduction gate active on 0 steps, shippedLessonSteps = derivedLessonSteps = **N = 1200**.
- lessonRecipe600: 600 steps validated.

**Benchmark (offscreen):** solver-only GPU median 15.979 ms; solver plus slice 29.587 ms.

## Report sections

- `docs/3d-phase7-verification.md`, "## Gap-closure re-verification — 2026-11-22 (G-07-2, G-07-5)":
  - the recipe and why the seed speed was lowered, with the Stage A table;
  - both amendments and the square-root transfer with palette anchors;
  - the fresh identity, the early-window table, and the 1800-step table;
  - N = 1200 and the Phase 9 handoff;
  - the benchmark, the fixes and the validator fix;
  - the matrix;
  - the user's 07-12 and 07-17 words, quoted.

  The 2026-11-08 recipe table, hashes and benchmark are labelled "historical — superseded by the gap-closure re-verification".
- `docs/3d-phase8-verification.md`, "## Gap-closure re-qualification — 2026-11-22": the environment, the old and new identity table, the inventory changes, the matrix, and the square-root palette note for the 08-09 reviewer. The 08-08 figures are labelled as the prior run.

## Still NOT TESTED / NOT MEASURED / PENDING

- VoiceOver, the macOS 26 runtime and physical multitouch: NOT TESTED.
- Displayed frame pacing: NOT MEASURED.
- manualVisualReview in the machine evidence: PENDING.
- The 08-09 checklist: unchecked.
- Requirement statuses and 07-UAT.md: unchanged; `/gsd-verify-work` owns them.

## Deviations from Plan

- **Validator constant changed during regeneration,** by explicit user decision. The constant was stale, not fitted to results: it predated a resource that the validator's own independent layout already listed. The plan's prohibition P-07-13-2 was raised with the user before acting.
- **Inline execution** in the orchestrator session, at the user's request.

## Task Commits

1. `40c0e70` test(07-13): reset payload total must follow the independent inspection inventory (RED)
2. `1502d69` fix(07-13): derive the inspection reset payload total from the independent inventory
3. docs(07-13): this commit, with both report sections, the SUMMARY and STATE

## Self-Check: PASSED

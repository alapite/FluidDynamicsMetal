---
phase: 07-first-3d-fluid-vertical-slice
plan: 12
subsystem: human-reobservation-checkpoint
tags: [human-verify, uat-gap-closure, 3d-slice, paused-2d-switching, blocking-checkpoint]

requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: 07-10 paused-2D presentation fix, 07-11 calibrated 3D lesson recipe
provides:
  - Exact reviewed Mac Debug app identity record (.build/07-12-review-app.json)
  - Verbatim, attributed user re-observation of UAT tests 2 and 5 on that build
  - G-07-5 human re-observation PASS; G-07-2 OPEN (not closed)
affects: [07-13, 07-verify-work, 09-repeatable-3d-advection-lesson, 10-volume-view]

plan_head_before: fa35ab9ed0285579ad4c45a6b0e0c419c8880a21
plan_head_after: fa35ab9ed0285579ad4c45a6b0e0c419c8880a21

actuals:
  tokens: 0
  tasks: 2
  commits: 0

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "G-07-2 is NOT closed: the user reports the 3D slice is hard to interpret (returning dye is very dim, the initial patch is small, the run feels too short). Per plan, the plan stops here and 07-13 does NOT start."
  - "G-07-5 is closed by human re-observation: the user reports all test 5 checks pass, plus the optional Command-M check."

requirements-completed: []

coverage:
  - id: D1
    description: "Exact app under review built from commit fa35ab9 with root-app metallib byte-identical to the default-DerivedData build"
    requirement: "SIM-05"
    verification:
      - kind: other
        ref: ".build/07-12-review-app.json (rootAppMetallibSHA256 == derivedDataMetallibSHA256)"
        status: pass
    human_judgment: false
  - id: D2
    description: "UAT test 2 re-observation (3D slice motion and depth read, G-07-2)"
    requirement: "SIM-05"
    verification:
      - kind: manual
        ref: "User statement, 2026-11-21 (verbatim below)"
        status: fail
    human_judgment: true
    rationale: "Perceived motion and depth read are human judgments; the user reported issues, so G-07-2 stays open"
  - id: D3
    description: "UAT test 5 re-observation (direct paused 2D lesson switching, paused Step, 3D-to-2D return, G-07-5) and optional Command-M check"
    requirement: "SIM-06"
    verification:
      - kind: manual
        ref: "User statement, 2026-11-21 (verbatim below)"
        status: pass
    human_judgment: true
    rationale: "On-screen canvas presentation is a human judgment; user reported PASS"

duration: n/a (human-gated; Task 1 about 51 s of build and smoke work)
completed: 2026-11-21
status: complete
outcome: "PARTIAL - checkpoint resolved with issues. G-07-5 human re-observation passed. G-07-2 NOT closed (open issue). 07-13 must not start."
---

# Phase 7 Plan 12: Human Re-observation of UAT Tests 2 and 5 Summary

**The exact fa35ab9 app was built, hash-identified and launched; the user then confirmed 2D switching (G-07-5, test 5, plus Command-M) now passes, but reported the 3D slice (G-07-2, test 2) is still hard to interpret, so G-07-2 remains open and 07-13 must not start.**

## Outcome at a glance

| Gap | UAT test | User-reported outcome | Gap status |
|---|---|---|---|
| G-07-2 | Test 2: 3D slice motion and depth | ISSUE (see sub-findings) | **OPEN - not closed** |
| G-07-5 | Test 5: direct paused 2D switching | All checks now pass | Human re-observation PASSED |
| LES-06 side check | Command-M with Simulation Controls key | PASS (user-reported) | n/a (optional check) |
| Failure-path optional check | One-shot Debug fault | Not requested | NOT TESTED |
| VoiceOver / physical-device input | n/a | Not part of this plan | NOT TESTED |

No approval is inferred beyond the user's written statements. `07-UAT.md` results and `REQUIREMENTS.md` statuses were deliberately not edited; `/gsd-verify-work` owns those.

## Task 1: Reviewed app identity (PASS)

Recorded in `.build/07-12-review-app.json` (gitignored, local evidence):

| Item | Value |
|---|---|
| Reviewed commit | `fa35ab9ed0285579ad4c45a6b0e0c419c8880a21` |
| Root-app executable (stub) SHA-256 | `398ec38146ce001cd0b64824a70c410463cf00c56d9c6aa02551292e2ba1476e` |
| Root-app `default.metallib` SHA-256 | `7be2e08aec0285c41598aa8a4be8a3622b2b546bf63a7059bb99965f007bd4cb` |
| Default-DerivedData `default.metallib` SHA-256 | `7be2e08aec0285c41598aa8a4be8a3622b2b546bf63a7059bb99965f007bd4cb` (equal) |
| Root-app debug dylib SHA-256 (extra key `rootAppDebugDylibSHA256`) | `12f618f9d33dc2ded1af101ce5eef4be43887320481a6c873a122831b9dd8ba2` |
| AGENTS.md no-override Mac build | exit 0 (4 s) |
| `./build-macos.sh` | exit 0 (7 s) |
| `python3 -m unittest Tests.Integration.test_educational_release` | exit 0 (40 s), "PASS: educational production engine" |
| Launched | 2026-11-21T07:45:06Z, PID 67837, no failure arguments |

A stray earlier instance (PID 6818, a scratchpad baseline build launched with `--fluid3d-test-failure=depth`) was quit before launch. Logs: `.build/07-12-macbuild.log`, `.build/07-12-build-macos.log`, `.build/07-12-smoke.log`. The Task 1 outputs are gitignored, so there is no Task 1 commit.

## Task 2: User responses (verbatim)

Source: the user, received 2026-11-21 (response relayed to the executor; summary written at 2026-11-21T07:57:48Z).

> "For test 2, I do see the patch fade and come back somewhat, but the brightness as it returns is very low, and so it's hard to interpret what is going on. Part of the problem seems to be that the patch is relatively small to begin with. Another issue is that there are only 500 timesteps, which is barely enough time to see anything happening.
>
> For test 5, all checks now pass.
>
> The Command-M check also passes."

### Test 2 (G-07-2): ISSUE - gap NOT closed

The user did not say the early motion read clearly or that the slice read as a cut through a moving 3D blob. They said they saw the patch fade and come back "somewhat". The yes/no question in how-to-verify step 5 was not answered affirmatively, and nothing here records approval.

Distinct sub-findings, each from the user's own statement:

- **(a) Returning dye brightness is very low.** As the dye returns to the slice it is dim, which the user says makes it hard to interpret what is happening.
- **(b) The initial patch still reads as relatively small.** The user attributes part of the problem to this.
- **(c) The run length is too short to see the phenomenon.** The user reports "only 500 timesteps", described as "barely enough time to see anything happening". Run length being too short to see the phenomenon is itself a finding, whatever the exact count.

Factual note on (c), not a correction of the user's observation: the source specifies lessons, including `.dyeAdvection3D`, to complete at 600 steps (`SimulationState.lessonSteps = 600`; `isLesson` is true for every mode except Free Play). The user's figure is 500. I did not observe the app and have not established why 500 was perceived (for example the point where the dye was visible again, or a counter value read during viewing). Either way the finding stands: the visible-return phase happens late and is brief.

Relation to 07-11 data, which already predicted this behaviour (from `07-11-SUMMARY.md`, production-solver 600-step lesson run, recipe speed 0.17, centre (0.66, 0.44, 0.59), radius 0.17):

| Step | slice peak | section area (>= 0.1) | volume peak |
|---:|---:|---:|---:|
| 200 | 0.053 | 0 | 0.582 |
| 300 | 0.095 | 0 | 0.437 |
| 400 | 0.147 | 45 | 0.355 |
| 500 | 0.184 | 69 | 0.295 |
| 600 | 0.201 | 90 | 0.253 |

The section area is 0 at steps 200 and 300 and has recovered to only 90 samples by step 600, with the slice peak at 0.053 at step 200. The 07-11 evidence itself recorded that the volume dye peak is only 0.253 at step 600. The 07-11 numeric gates covered the early window (steps 10 to 48) and a reported-not-gated 600-step check (amendment E7). Sub-findings (a) and (b) are therefore consistent with the recorded numbers (dim return, small and short-lived section), but the numbers show only that the user's observation matches the measured behaviour; no cause was diagnosed in this plan.

Why this was not auto-fixed: this plan is a human-verify gate with no source changes, and what to change (initial blob size, dye gain or colour mapping for low values, run length, or the fade-and-return structure of the lesson) is a design decision. Changing the recipe would also invalidate the 07-11 gates and the Phase 9 solver-cliff constraint, so it needs its own plan.

### Test 5 (G-07-5): PASS (user-reported)

The user reported "all checks now pass" for test 5, which covers how-to-verify steps 6 to 8: direct paused 2D lesson switching, paused Step and Restart, and the 3D-to-2D return. G-07-5 human re-observation passed. The user gave no per-step notes beyond "all checks now pass".

### Optional checks

- **Command-M side check (LES-06):** user-reported PASS. The user did not separately report the step-counter-unchanged-while-minimized part; "passes" is recorded as stated.
- **Failure-path check (step 9):** not requested by the user. NOT TESTED.

## Deviations from Plan

None. The plan executed as written: Task 1 ran as a tracer and passed, and the Task 2 checkpoint returned an issue report, which the plan says to record as an open issue before stopping.

## Next steps

- **07-13 must NOT start.** Per the plan, "07-13 starts only if both tests are approved"; test 2 was not. 07-13 (full evidence regeneration, about an hour) would be run against a recipe the user has just flagged, and its evidence would be invalid if the recipe then changes. Nothing was started or modified for 07-13.
- G-07-2 needs a further diagnosis and replan: run `/gsd-plan-phase 7 --gaps`, or record the user's observations in `07-UAT.md` through `/gsd-verify-work 7`, which owns the UAT results. The three sub-findings (dim return, small patch, run length) are the inputs.
- Any recipe change reopens the 07-11 early-window gates (E1 to E7) and the Phase 9 solver-cliff constraint (speed 0.17 has max input divergence 7.61e-4; the unsafe band is roughly x1.6 to x3.3 of the original 0.12 seed). A re-planned fix should respect those or amend them in a dated, additive step.
- The opaque single-slice depth limit remains Phase 10 (volume view) scope. Whether sub-finding (a) can be fixed by display mapping inside Phase 7 or needs Phase 10 is for the replan to decide; this summary does not decide it.
- G-07-5 needs no further work from this plan, subject to `/gsd-verify-work` recording it.

## Issues Encountered

- Open: G-07-2 (above).
- The running app (PID 67837) was left running, as instructed.

## Known Stubs

None.

## Threat Flags

None. No source, network, auth or schema changes were made in this plan.

## Self-Check: PASSED

- `.build/07-12-review-app.json` present; metallib hashes equal.
- HEAD is `fa35ab9` at summary time with a clean tree before this file; `commits: 0` is measured (`git rev-list --count fa35ab9..HEAD` = 0) and legitimate because Task 1 outputs are gitignored and Task 2 is a human checkpoint.

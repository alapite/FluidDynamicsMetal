---
phase: 07-first-3d-fluid-vertical-slice
plan: 17
subsystem: human-review
tags: [uat, g-07-2, human-verify, checkpoint, macos, transport-layout]

g07_2_a_returning_brightness: approved
g07_2_b_patch_size: approved
g07_2_c_run_length: approved
g07_2_d_early_motion: approved
g07_2_outcome: approved

requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: 07-14 square-root display, 07-15 recipe (seed speed 0.155, blob B3), 07-16 3D lesson length 1200
provides:
  - User approval of UAT test 2 re-observation (G-07-2 sub-findings a-d) on the exact reviewed build
  - Mac transport fix found during review (Step no longer moves when Run becomes Resume)
affects: [07-13]

actuals:
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Fixed-width title-changing buttons so adjacent controls never shift under the pointer"

key-files:
  created:
    - .planning/phases/07-first-3d-fluid-vertical-slice/07-17-SUMMARY.md
  modified:
    - Sources/macOS/RenderViewController.swift
    - Tests/UI/macOS/HUDUITests.swift

key-decisions:
  - "The review-blocking Step defect was fixed inline (RED 1a20dab, fix a89f46b) and the app was rebuilt and re-identified before the user resumed the review."

duration: approximately 25 min
completed: 2026-11-21
---

# Phase 7 Plan 17: Human re-observation of UAT test 2 (G-07-2) — Summary

**The user approved all four G-07-2 sub-findings on the rebuilt Mac app at commit `a89f46b`: seed speed 0.155, 3D lesson length 1200 steps.**

## Reviewed app identity (`.build/07-17-review-app.json`)

| Key | Value |
|---|---|
| commit | `a89f46b0cf6311f9989a894aa2652f5ddddbe630` |
| rootAppExecutableSHA256 | `398ec38146ce001cd0b64824a70c410463cf00c56d9c6aa02551292e2ba1476e` |
| rootAppMetallibSHA256 | `394571a004e383523dee440ec460d2f20ba1f7432f12ded487dda551dd516b91` |
| derivedDataMetallibSHA256 | `394571a004e383523dee440ec460d2f20ba1f7432f12ded487dda551dd516b91` (equal) |
| threeDLessonSteps | 1200 |
| seedMaximumVectorSpeed | 0.155 |
| macBuild / build-macos / smoke exit codes | 0 / 0 / 0 |
| launchedAtUTC / PID | 2026-11-21T17:44:54Z / 94829 |

The Debug executable is a stub launcher; the app code lives in the debug dylib, so the stub's hash matches 07-12's. The metallib hashes identify this build.

## Defect found during the review, and its fix

The first launch was built from `ce582ac`. During step 2, the user reported, verbatim:

> "There's a significant problem with executing step 2 - as soon as I hit the "step" button a second time, the steps automatically continue on their own, unless I hit "pause". By that point it's usually at 60 steps or more."

**Cause:** in a lesson at Step 0, the Mac Pause button reads "Run". After one step it reads "Resume", which is wider. That pushed Step 25 pt to the right (UI-test measurement: x 331.5 → 356.5), so the second click landed on Resume and the lesson ran on its own. The same layout was used for the 2D lessons. The iOS transport uses equal widths and was not affected. The defect predates this gap round; it is not a regression from 07-16.

**Fix:**
- `1a20dab` (RED): `testRepeatedStepClicksAtSamePlaceStayPaused` clicks one fixed screen point three times, in the 3D lesson and in the first 2D lesson. Before the fix, click 2 did not show Step 2.
- `a89f46b`: Pause now has a fixed width that fits its widest title (Run, Resume or Pause).
- **Verification:**
  - The new test passes, along with 7 other layout, transport and lesson HUD tests and the 26 state tests.
  - The full 26-test HUD suite was not rerun here; 07-13 does that.
- The app was then rebuilt, re-identified (the table above) and relaunched. The user restarted the review from step 1.

## User response (verbatim)

- **Attribution:** the user (project owner), in this session.
- **Time:** 2026-11-21, after the 17:44:54Z relaunch.

> "approved"

As the resume signal, "approved" approves all four sub-findings:

| Sub-finding | Outcome |
|---|---|
| (a) Returning dye bright enough to interpret | approved |
| (b) Starting patch large enough | approved |
| (c) Run long enough to see fade and return | approved |
| (d) Patch visibly moves or changes shape within about 10-20 steps at seed speed 0.155 | approved |
| Optional 2D completion check | no separate response given |

G-07-2 is approved by the user. 07-UAT.md results and REQUIREMENTS.md statuses are unchanged; /gsd-verify-work owns them. These remain NOT TESTED: VoiceOver, the macOS 26 runtime, and physical multitouch.

## Task Commits

1. `1a20dab` test(07-17): repeated Step clicks at one place must keep a lesson paused (RED)
2. `a89f46b` fix(07-17): keep the Mac Step button still when Run becomes Resume

## Deviations from Plan

- The plan's files list contains no source change. A review-blocking transport defect had to be fixed before the user could do step 2. The fix was test-first, inline at the user's earlier request, and the reviewed identity was re-recorded for the new commit.

## Next Phase Readiness

07-13, the full regression matrix and verification documents, can start. Its approval gate reads `g07_2_outcome: approved`. It should include the new HUD test in the full Mac run.

## Self-Check: PASSED

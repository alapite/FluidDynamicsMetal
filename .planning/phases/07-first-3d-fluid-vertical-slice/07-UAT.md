---
status: complete
phase: 07-first-3d-fluid-vertical-slice
source: [07-VERIFICATION.md]
started: 2026-11-20T20:10:00Z
updated: 2026-11-20T21:26:06Z
---

## Current Test

[testing complete]

## Tests

### 1. In the running Mac app, open the Simulation menu and the toolbar/selector; choose 3D Dye Advection.
expected: A non-selectable '3D' group lists '3D Dye Advection' separately from the 2D modes; 2D titles and Command-1..4 are unchanged; selecting it enters the lesson.
result: pass

### 2. Observe the fixed slice at step 0 and after Run for several seconds / after several Steps.
expected: A nonblank amber dye slice (X right, Y up, Z=0.5) that visibly changes shape over steps; the learner can read it as a tumbling volume rather than a flat 2D animation.
result: issue
reported: "The first thing I've noticed is that it takes many more than 5-10 steps to see noticeable movement of the dye patch - more like 40-50. The second issue is that the patch doesn't really give a convincingly 3d impression. It starts by taking relatively little of the cube volume, and during transformation it doesn't give strong depth cues to convince me that I'm not just viewing a 2d slice."
severity: major

### 3. Run, Pause, Resume and Step on the 3D lesson; watch the step counter.
expected: Entry is paused at 'Step 0'; Run/Pause/Resume update the counter; each paused Step advances exactly one.
result: pass

### 4. While running and while manually paused, switch to another app / minimize, wait, then return.
expected: Counter frozen while inactive; no burst of catch-up steps on return; a manually paused lesson stays paused.
result: pass
reported: "With the new test procedure you've suggested, G-07-4 records as a pass."
note: "Initial run reported as issue (\"For part A, while it's hard to be sure due to the speed at w...\"); diagnosis (.planning/debug/3d-running-continues-while-inactive.md) found freeze logic correct but unobservable at ~60 steps/s with the counter panel hidden while inactive, and Cmd-M inert while the controls panel is key. Re-tested 2026-11-20 with a timed procedure (switch away at ~120-180 steps, wait 10 s): pass. Side finding (not a test failure): Cmd-M does nothing while the controls panel is the key window."

### 5. Switch from 3D back to Free Play and each 2D lesson (also trigger the injected 3D failure path if available).
expected: Established 2D selection/reset defaults, no stale mouse/touch input, native recovery message and retry work.
result: issue
reported: "What actually shows up depends on the order in which I select items. If I select \"Free Play\" first, then I can successfully initiate the other selections right afterwards, but switching directly between the other 2d choices doesn't really alter what's shown on the canvas (though it does change the control panel). Selecting 3D Dye Advection does successfully change the canvas state though, no matter what was selected previously."
severity: major

### 6. Keyboard-only traversal and VoiceOver pass over the 3D panel (Phase 8 controls now share the panel).
expected: Labelled controls, logical focus order, readable panel contrast; panel copy matches or is formally superseded by the Phase 8 UI contract.
result: pass
reported: "Part A: pass; Part B: skipped; Part C: pass"
note: "Keyboard traversal and readability passed. VoiceOver (Part B) was skipped by the user and remains NOT TESTED."

## Summary

total: 6
passed: 4
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-07-2
  truth: "A nonblank amber dye slice (X right, Y up, Z=0.5) that visibly changes shape over steps; the learner can read it as a tumbling volume rather than a flat 2D animation."
  status: failed
  reason: "User reported: The first thing I've noticed is that it takes many more than 5-10 steps to see noticeable movement of the dye patch - more like 40-50. The second issue is that the patch doesn't really give a convincingly 3d impression. It starts by taking relatively little of the cube volume, and during transformation it doesn't give strong depth cues to convince me that I'm not just viewing a 2d slice."
  severity: major
  test: 2
  artifacts: []
  missing: []

- gap_id: G-07-5
  truth: "Established 2D selection/reset defaults, no stale mouse/touch input, native recovery message and retry work."
  status: failed
  reason: "User reported: What actually shows up depends on the order in which I select items. If I select \"Free Play\" first, then I can successfully initiate the other selections right afterwards, but switching directly between the other 2d choices doesn't really alter what's shown on the canvas (though it does change the control panel). Selecting 3D Dye Advection does successfully change the canvas state though, no matter what was selected previously."
  severity: major
  test: 5
  artifacts: []
  missing: []

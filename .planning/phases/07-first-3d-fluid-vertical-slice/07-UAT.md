---
status: diagnosed
phase: 07-first-3d-fluid-vertical-slice
source: [07-VERIFICATION.md]
started: 2026-11-20T20:10:00Z
updated: 2026-11-20T21:43:10Z
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
  root_cause: "Uncalibrated Phase 7 recipe, not a solver/renderer defect: seed peak speed 0.12 (0.128 cells/step max) and the dye blob (centre 0.42,0.48,0.52, r=0.12) sits near the low-speed core (centroid drift 0.052 cells/step), so visible change (RMS ~0.05, 1-2 cell shift) first appears at step 35-46; the z=0.5 plane cuts the blob near its equator and it drifts only 1.4 cells in z by step 48, so the section barely changes size and only dims. Preregistered visibility gates (RMS>=0.005, z-travel>=h/2 at steps 24/48) are ~10x weaker than human visibility. Opaque single-sheet depth limit is inherent (Phase 10 volume view). Latent solver cliff: seed speeds ~x1.6-x3.3 cross the 1e-3 pre-projection divergence line and the 1000x reduction rule fails (x3 hard-failed at step 164)."
  artifacts:
    - path: "Sources/Shared/ExperimentRecipes3D.swift"
      issue: "maximumVectorSpeed=0.12, blobCenter (0.42,0.48,0.52), blobRadius=0.12 uncalibrated"
    - path: "docs/3d-numerical-contract.md"
      issue: "candidate visibility gates (lines ~110-117, hash-pinned prefix) too weak; needs dated amendment after END PREREGISTERED CONTRACT"
    - path: "Tests/Integration/test_fluid3d.swift"
      issue: "evolution-visibility assertions and hard-coded blob literals (~3551-3564, 3733-3744)"
    - path: "Sources/Shared/Shaders3D.metal"
      issue: "1000x reduction rule / internal stop target (~774, 1468-1470) leaves only ~1007-1088x margin in the x1.6-x3.3 speed band"
  missing:
    - "Re-place/resize the blob off-plane in faster flow (r~0.16-0.18) so it sweeps through z=0.5, keeping step-0 slice peak >=0.5"
    - "Keep seed speed <=x1.6 (or add PCG margin, e.g. continue to >=1500x reduction when input >=1e-3, never relaxing the 1000x rule)"
    - "Add human-calibrated early-window gates (slice RMS ~0.04 by step 10-20, pixel-change and section-area change) as a dated contract amendment"
    - "Add a 600-step lesson-recipe check; update evolution-visibility literals; regenerate test_fluid3d evidence and Phase 8 inspection evidence"
  debug_session: .planning/debug/3d-slice-weak-motion-and-depth.md

- gap_id: G-07-5
  truth: "Established 2D selection/reset defaults, no stale mouse/touch input, native recovery message and retry work."
  status: failed
  reason: "User reported: What actually shows up depends on the order in which I select items. If I select \"Free Play\" first, then I can successfully initiate the other selections right afterwards, but switching directly between the other 2d choices doesn't really alter what's shown on the canvas (though it does change the control panel). Selecting 3D Dye Advection does successfully change the canvas state though, no matter what was selected previously."
  severity: major
  test: 5
  root_cause: "Regression from 08-03 (commit b4b6be6): Renderer.redrawIfPaused() presents paused 2D frames via drawPresentationOnly(in:), which reads view.currentDrawable outside an MTKView draw cycle; MTKView caches that drawable until its next real draw(), so after the first paused redraw every further one renders correct pixels into an already-presented drawable that never reaches the screen. Free Play (display link), Run and 3D (view.draw() since f148b64) retire the drawable, so only paused 2D lesson->lesson switches show stale content. Reset/state logic is correct. Same latent issue in paused 2D Step via scheduleStepDrain; shared code so iOS is affected too."
  artifacts:
    - path: "Sources/Shared/Renderer.swift"
      issue: "redrawIfPaused() 2D branch (~311-322) uses drawPresentationOnly; scheduleStepDrain() 2D branch (~250-268) calls draw(in:) directly; draw(in:presentationOnly:) takes view.currentDrawable (~627, 698)"
  missing:
    - "In 2D branches of redrawIfPaused() and paused scheduleStepDrain(), call view.draw() when view.delegate === self (as 3D does), keeping drawPresentationOnly as fallback for headless fixtures"
    - "Preserve presentation-only (no step consumption) semantics via a flag around view.draw(), like drawingQueuedStep"
    - "Regression test: MTKView subclass/spy asserting consecutive paused 2D redraws never reuse a presented drawable (or count view.draw() calls on paused lesson switch)"
  debug_session: .planning/debug/2d-lesson-switch-canvas-not-reset.md

## Additional Findings (not test failures)

- "Cmd-M (performMiniaturize:) is disabled while the Simulation Controls NSPanel is key (styleMask lacks .miniaturizable), so minimizing from the panel silently does nothing; the step counter panel also hides on deactivation with no inactive indicator. Source: .planning/debug/3d-running-continues-while-inactive.md. Minor; candidate for the gap-closure plan."

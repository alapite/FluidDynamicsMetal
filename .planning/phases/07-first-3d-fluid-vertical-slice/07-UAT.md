---
status: testing
phase: 07-first-3d-fluid-vertical-slice
source: [07-VERIFICATION.md]
started: 2026-11-20T20:10:00Z
updated: 2026-11-20T20:10:00Z
---

## Current Test

number: 1
name: In the running Mac app, open the Simulation menu and the toolbar/selector; choose 3D Dye Advection.
expected: |
  A non-selectable '3D' group lists '3D Dye Advection' separately from the 2D modes; 2D titles and Command-1..4 are unchanged; selecting it enters the lesson.
awaiting: user response

## Tests

### 1. In the running Mac app, open the Simulation menu and the toolbar/selector; choose 3D Dye Advection.
expected: A non-selectable '3D' group lists '3D Dye Advection' separately from the 2D modes; 2D titles and Command-1..4 are unchanged; selecting it enters the lesson.
result: [pending]

### 2. Observe the fixed slice at step 0 and after Run for several seconds / after several Steps.
expected: A nonblank amber dye slice (X right, Y up, Z=0.5) that visibly changes shape over steps; the learner can read it as a tumbling volume rather than a flat 2D animation.
result: [pending]

### 3. Run, Pause, Resume and Step on the 3D lesson; watch the step counter.
expected: Entry is paused at 'Step 0'; Run/Pause/Resume update the counter; each paused Step advances exactly one.
result: [pending]

### 4. While running and while manually paused, switch to another app / minimize, wait, then return.
expected: Counter frozen while inactive; no burst of catch-up steps on return; a manually paused lesson stays paused.
result: [pending]

### 5. Switch from 3D back to Free Play and each 2D lesson (also trigger the injected 3D failure path if available).
expected: Established 2D selection/reset defaults, no stale mouse/touch input, native recovery message and retry work.
result: [pending]

### 6. Keyboard-only traversal and VoiceOver pass over the 3D panel (Phase 8 controls now share the panel).
expected: Labelled controls, logical focus order, readable panel contrast; panel copy matches or is formally superseded by the Phase 8 UI contract.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps

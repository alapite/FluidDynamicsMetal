---
phase: 08-spatial-inspection
plan: "07"
subsystem: testing
tags: [swift, metal, complete-state, presentation-independence, queue-ordering, tdd]
requires:
  - phase: 08-spatial-inspection
    provides: Production solver, renderer scheduling, spatial presentation and passive tracers from 08-01 through 08-06
provides:
  - Fail-closed named evolution inventory with queue-ordered complete GPU snapshots
  - Exact paused preservation and independent equal-step solver/tracer comparisons
  - Deterministically initialized optional pressure traces and retained status ownership
  - Fresh numerical, renderer, spatial, two-target build and Mac regression evidence
affects: [08-08, 08-09, 09-repeatable-3d-advection-lesson]
tech-stack:
  added: []
  patterns:
    - Explicit diagnostic registration checked against independent live allocation ownership
    - Exact within-session identity and bytes distinguished from fresh-session semantic equivalence
    - Finite-first per-resource comparisons with archived discrete metadata
key-files:
  created:
    - .planning/phases/08-spatial-inspection/08-07-REVIEW.md
    - .planning/phases/08-spatial-inspection/08-07-SUMMARY.md
  modified:
    - Sources/Shared/FluidSimulation3D.swift
    - Sources/Shared/PressureProjection3D.swift
    - Sources/Shared/Renderer.swift
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
    - Tests/UI/macOS/HUDUITests.swift
key-decisions:
  - "Retain reset/latest and every submitted status until callback processing; stage all owned slots after queue completion."
  - "Compare every owned voxel and buffer byte, excluding unowned texture-readback row padding."
  - "Normalize only process-local allocation identity/session generation between fresh sessions, never numerical or discrete state."
  - "All Phase 8 requirements remain pending and 08-09 human review remains mandatory."
patterns-established:
  - "Comparator negative tests corrupt staging copies, not production solver resources."
  - "Optional trace reuse clears the entire allocation, not just recorded genuine iterations."
requirements-completed: []
duration: approximately 95 min
completed: 2026-11-14
---

# Phase 8 Plan 07: Complete-State Inspection Independence Summary

**Complete GPU resource snapshots now prove exact paused preservation and equal-step fluid/tracer independence across visible, hidden, alternating and nil-drawable renderer schedules.**

## Performance and scope

- **Duration:** Approximately 95 minutes including repeated numerical/UI gates.
- **Started:** Approximately 2026-11-14T22:18Z; exact start timestamp was not captured.
- **Completed:** 2026-11-14, approximately 23:53Z.
- **Tasks:** 2/2.
- **Implementation/test files:** 6; summary and distinct inline review are additional documentation.
- Sequential current-checkout execution; no branch/worktree changes, model override,
  agent dispatch, 08-08/09 execution or phase-level completion.

## Accomplishments

### Task 1 — Complete snapshot and mutation detector

- Added scoped diagnostic buffer registration for the simulation failure latch,
  projection standalone latch and entire reduction workspace. Every status exposes
  its state and optional trace allocation for ordered diagnostic staging.
- Renderer retains the validated reset status, latest completed step status, and
  all submitted statuses until callback processing. Diagnostic metadata includes
  mode, encoded/consumed/completed counters, pending work, pause/inactivity/reset/
  cap/failure state, session token, drain scheduling, input emptiness and status roles.
- Registered `Fluid3DTests.test_inspection_independence` /
  `inspection-independence`, with a separately hashed inspection-contract source
  and reference inventory. Existing snapshot and benchmark helpers remain intact.
- Audit pins actual field/buffer names, shapes, formats and lengths, independently
  traverses live owned allocations, and rejects missing/extra/renamed/resized
  resources. Texture data is decoded without staging row padding; all voxel and
  buffer bytes are included.
- **37 reset resources / 33,776,184 payload bytes:** 32 texture generations,
  reduction workspace, two latches, one in-place 8,192-byte tracer position buffer,
  and reset status. Tracers allocate no ping/pong/scratch storage.
- **39 resources / 33,786,728 bytes** with the additional traced status and full
  10,240-byte optional trace. Trace initialization/reuse now clears its entire
  allocation, fixing a real exposed nonfinite-tail reset defect.
- **160 negatives passed:** per-resource staging-byte mutations, omission, rename,
  resize, extra/duplicate resources, nonfinite exact/approximate comparisons,
  discrete metadata and allocation-role changes. Detector tests never mutate
  production solver resources; a separate poisoned-trace reuse test explicitly
  verifies deterministic reset of recycled diagnostic storage.

### Task 2 — Presentation independence and Restart

- **29 paused cases at evolved step 2 with pendingSteps=2** preserve all resources
  byte-for-byte, physical identity, ping/pong roles, counters, pending work and
  input state. Cases cover all planes/depths 0/30/50/100%, front/back/edge-on views,
  minimum/maximum zoom, gesture-yaw value path, Reset Camera, Centre Slice,
  visibility, wide/tall/320×240 canvases, 1×/2× backing scales and zero viewport.
  Positive descriptor/value, matrix, image or viewport checks prevent inert edits
  from passing. Direct 3D input entry points introduce no contacts.
- A separately reset `FluidSimulation3D` followed by `TracerSystem3D` advances
  without Renderer or visualization. Four independently initialized production
  Renderer cases—shown, hidden, alternating and nil drawable—compare at
  **0/1/24/48**, with varying plane/depth/camera, 0/1/2 explicit redraws per step,
  actual drawable sizes, aspect ratios and backing scales.
- **All compared resources were byte-identical; maximum absolute error 0.**
  Acceptance remains finite-first absolute **2e-6** for floating resources, exact
  status/latches/discrete state/seeds/wall zeros, and exact bytes/identity for
  within-session paused comparisons. No threshold was fitted or relaxed.
- Actual usable drawable reads were **195 shown / 196 hidden / 195 alternating /
  0 nil-drawable**. Nil/zero-size presentation does not suppress advancement.
  Re-showing hidden tracers neither catches up nor reseeds.
- Each schedule captures reset/latest/three submitted slots **before callback
  drain**: **41 resources / 33,777,400 bytes**, five distinct accepted status
  objects, encoded step 4 versus completed count 1. GPU bytes are decoded only
  after the staging fence; callbacks then drain normally.
- Restart retains nondefault yaw/elevation/zoom, YZ plane, 27% depth and hidden
  tracers; returns paused at step 0 with no pending input/work; matches the full
  independent reset inventory exactly across new allocations; step 1 matches
  again. This is not Phase 9 all-speed/600-step repeatability acceptance.
- The new report embeds freshly executed initial/restart allocation, pipeline,
  tracer allocation/reset, reset/projection, active depth/retry, tracer advance,
  active projection-failure and stale-callback recovery assertions.

## Task commits and TDD evidence

1. **Task 1 RED:** `e6fc4b0` — full GPU ownership audit fails:
   registered 35 versus owned 37 allocations.
   `.build/08-07-task1-red.log`.
2. **Trace-reset RED:** `dd085d5` — nonfinite `status/traced/trace` tail detected
   after a genuine traced projection.
   `.build/08-07-task1-trace-red.log`.
3. **Task 1 GREEN:** `722a48b` — complete diagnostics, retained ownership and trace
   initialization. Fast state/reference plus GPU fixture **3/3 passed**:
   `.build/08-07-task1-green.log`.
4. **Task 2 RED:** `c187c36` — production fixture has no required paired schedules:
   `.build/08-07-task2-red.log`.
5. **Task 2 GREEN:** `fb6d309` — complete schedules, Restart, paused and failure
   checks. Required five-test command **5/5 passed**, 247.301 s:
   `.build/08-07-task2-green.log`.
6. **Inherited HUD regression repair:** `e466223` — update approved note copy and
   title-bar test coordinate; focused **2/2 passed**:
   `.build/08-07-ui-repair.log`.
7. **Inline-review RED:** `8f79f3f` — collection-held allocation audit gap and
   archived metadata guard:
   `.build/08-07-review-red.log`.
8. **Inline-review GREEN:** `4661f18` — container traversal, archived metadata,
   complete trace negatives, positive resize checks and corrected three-pipeline
   spatial fixture. Review command **3/3 passed**:
   `.build/08-07-review-green.log`.

Both plan tasks have actual observed RED/GREEN runs and atomic commits.

## Final verification and exact evidence paths

| Gate | Result | Evidence |
|---|---|---|
| Mac Debug, arm64, no signing/version/target override | PASS | `.build/08-07-mac-build.log` |
| Generic iOS Simulator Debug, no overrides | PASS | `.build/08-07-ios-build.log` |
| Full Mac state + HUD suite | **47/47: 25 state + 22 UI** | `.build/08-07-mac-tests-final.log`, `.build/08-07-mac-tests-final.xcresult` |
| Final targeted integration matrix | **19/19**, 834.219 s | `.build/08-07-final-regressions-pass.log` |
| Source/reference/metrics freshness for 11 GPU reports | PASS | `.build/08-07-evidence-audit.log` |
| Diff whitespace check | PASS | `git diff 3901109..HEAD --check` |

The 19-test matrix comprises two fast state/reference drivers, eleven GPU
fixtures, and six existing renderer/educational regressions. Fast production
state compiled in 1.893 s and ran in 0.008 s; independent oracle compiled in
1.313 s and checked in 0.126 s. This is separate from the long GPU gate.

**Primary complete-state evidence:**

- `.build/inspection3d-evidence/inspection-independence.json` — complete named
  inventories, byte counts, all 160 negative cases, per-resource maximum error/
  byte-match, paused metadata/identity checks, 16 equal-step checkpoints, queued
  ownership records, Restart and embedded failure outcomes.
- `.build/fluid3d-evidence/inspection-independence.json` — identical report in
  the established report location, preserving old evidence consumers.
- `.build/fluid3d-evidence/inspection-independence.log` — fresh production
  harness/reference/Metal-validation run.

**Other fresh production reports and same-basename `.log` files:**

`.build/fluid3d-evidence/{inspection-routing,renderer-steps-and-inactivity,reset-finite,projection,advection-boundaries,tracer-evolution,transitions-and-failures,spatial-slices,tracer-occlusion,slice-palette}.json`.

The finite fixture includes its **600-step soak**, exact wall zeros and failure
latch recovery. Projection reruns all seven production families with the
unchanged 320 cap and primary 1e-5 gates. Tracer evolution reruns the independent
Double RK2 comparison and guarded scheduling. Established 2D solver, shader
names and Swift/Metal ABI are unchanged.

## Distinct inline review

**PASS with findings resolved**, performed inline against the original plan,
not by an independent agent. See `08-07-REVIEW.md`. Actual Swift symbol calls
exercise both Renderer and FluidSimulation3D; the pre-wave filename-based
key-link false negatives are not missing dependencies.

## Deviations from plan and issues encountered

1. **[Rule 1 — Bug] Undefined optional trace tail.** Found in Task 1's complete
   inventory. Clear allocation and each traced submission; RED/GREEN above.
   This is the plan-authorized deterministic reset repair, not a solver change.
2. **[Rule 3 — Regression blocker] Inherited HUD test expectations.** Full Mac
   run first failed on old note text and a drag point below the taller title
   bar. Changed only `Tests/UI/macOS/HUDUITests.swift`; focused and full gates
   pass. Original failure evidence remains `.build/08-07-mac-tests.log` and
   `.build/08-07-mac-tests.xcresult`.
3. **[Rule 3 — Regression blocker] Inherited two-pipeline spatial assertion.**
   Expanded regression run exposed the pre-tracer allocation count. Require
   all three actual named pipelines and reuse; no threshold weakening.
   Original failure: `.build/08-07-final-regressions.log`; focused repair:
   `.build/08-07-spatial-repair.log`; final 19-test matrix passes.
4. **Test setup correction:** The first active-depth fault requested the cached
   Retina dimensions and therefore did not allocate/fail. Request a genuinely
   new size derived from the current drawable. No production workaround.
   `.build/08-07-task2-green.log` is the later passing run. The earlier setup
   failure used that same output path, which was overwritten by the later run;
   it is described here, not claimed as a preserved standalone failure log.

Total additional regression repairs: **2**, both test-only and directly related
to Phase 8 integration. No new dependencies or architectural changes.
The iOS build retains the existing UIRequiresFullScreen deprecation and
AppIntents-metadata warnings. No user setup is required.

## Scope limits and next readiness

- **08-07 / Wave 7 is complete; next is 08-08 / Wave 8 only.**
- Phase 8 remains **executing**, 7/9 plans closed after tracking update.
- INS-01, INS-02, INS-03, INS-04 and CTRL-08 all remain **pending**.
  Summary `requirements-completed: []` intentionally honors the user's
  acceptance boundary rather than auto-completing plan-associated IDs.
- No 08-08 schema/regression-matrix/docs workflow, 08-09 human review,
  phase-level verification/completion or Phase 9 qualification was executed.
- Actual macOS 26 runtime, VoiceOver, physical pointer/trackpad feel/direction
  and physical-device multitouch remain **NOT TESTED**. Displayed frame pacing/
  FPS remains **NOT MEASURED**. Automated screenshots/events are not human
  visual/accessibility/input acceptance; 08-09 remains mandatory.

## Self-Check: PASSED

Both original task acceptance gates, final targeted production regressions,
two-target builds, complete Mac gate, evidence freshness, task commits and
distinct inline review are present. All listed implementation/review files
exist. No owned requirement or phase completion is claimed.

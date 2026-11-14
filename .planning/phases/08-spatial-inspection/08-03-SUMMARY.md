---
phase: 08-spatial-inspection
plan: "03"
subsystem: rendering
tags: [swift, metal, renderer, spatial-inspection, presentation-only]
requires:
  - phase: 08-spatial-inspection
    provides: Validated camera and slice state plus the depth-equipped spatial sheet renderer
provides:
  - Renderer APIs for committed 3D inspection state, camera reset, and slice centering
  - A presentation-only draw route that preserves accepted steps and simulation state
  - Transactional depth preparation, spatial viewport routing, and Restart-vs-selection semantics
  - Production renderer coverage for pending-step preservation, resize, recovery, and retry
affects: [08-04, 08-06, 08-07, 08-08]
tech-stack:
  added: []
  patterns:
    - Presentation-only draw calls bypass the ordinary logical-step drain
    - Candidate 3D depth resources are prepared before publishing the session
    - Spatial viewports use the actual drawable texture dimensions
key-files:
  created: []
  modified:
    - Sources/Shared/SimulationState.swift
    - Sources/Shared/Renderer.swift
    - Sources/Shared/FieldVisualization3D.swift
    - Tests/Integration/test_inspection3d_state.swift
    - Tests/Integration/test_inspection3d_state.py
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
key-decisions:
  - "Keep inspection state separate from 2D display/tuning state; 3D selection resets defaults, while Restart uses beginReset/finishReset and retains inspection choices."
  - "Inspection and resize redraws use an explicit no-advance route, leaving the normal encode-before-consume step path unchanged."
  - "Use CAMetalDrawable.texture dimensions for the spatial render target and point-scale calculation; MTKView.drawableSize can differ from the current offscreen drawable."
patterns-established:
  - "Paused presentation changes redraw directly without entering the queued-step drain."
  - "Prepare size-keyed spatial depth before candidate publication and on usable resizes; defer zero-sized dimensions."
requirements-completed: []
duration: approximately 41 min
completed: 2026-11-14
---

# Phase 8 Plan 03: Renderer Inspection Routing Summary

**The production renderer now applies committed camera/slice state through a no-advance presentation path, retains inspection choices on Restart, and recovers transactionally from spatial depth failures.**

## Performance

- **Duration:** Approximately 41 minutes.
- **Started:** 2026-11-14T08:16:43Z.
- **Completed:** 2026-11-14T08:57:23Z.
- **Tasks:** 2/2.
- **Files modified:** 7 implementation/test files.

## Accomplishments

- Added separate `SimulationState.inspection3D` ownership and guarded Renderer APIs for setting inspection state, resetting only the camera, and centering only the slice.
- Replaced paused `MTKView.draw()` redraws with an explicit presentation-only route. It preserves `pendingSteps`, counters, pause intent, input, and simulation textures; ordinary draw callbacks retain the existing exact-step path.
- Routed 3D presentation through `encodeInspection` over the full actual drawable texture, with drawable-to-point scaling and size-keyed depth preparation. Zero-size entry defers allocation; allocation failures leave a usable 2D session and can be retried.
- Distinguished explicit 3D selection/reselection (defaults) from Restart (retained plane, depth, camera, and visibility while resetting to paused step 0).
- Added production fixture assertions for queued-step preservation, bitwise-unchanged simulation fields, image/matrix changes, ordinary step draining, restart/reselection, zero-size resize, and depth failure/retry.
- Preserved the established 2D solver and Swift/Metal ABI.

## Task Commits

1. **Task 1: Separate presentation mutation, initial entry and restart in state** — RED `a0c862c`, supplementary defaults/reselection RED `de69e0b`, implementation `f92a17f`.
2. **Task 2: Wire spatial renderer updates without draining accepted steps** — RED fixture `1755db4`, implementation `b4b6be6`.

## Files Created/Modified

- `Sources/Shared/SimulationState.swift` — isolated inspection state and reset-versus-entry behavior.
- `Sources/Shared/Renderer.swift` — inspection APIs, presentation-only draws, spatial routing, depth preparation, and restart intent.
- `Sources/Shared/FieldVisualization3D.swift` — size-keyed depth preparation before renderer-session publication.
- `Tests/Integration/test_inspection3d_state.swift` and `.py` — state operation-scope and default/retention checks.
- `Tests/Integration/test_fluid3d.swift` and `.py` — registered renderer fixture, queue/resource assertions, and deterministic GPU-completion fencing.

## Decisions Made

- Camera/slice state is presentation-only and does not reuse 2D display options or tuning.
- Explicit 3D selection/reselection initializes defaults; Restart calls reset lifecycle operations without reinitializing inspection.
- The renderer uses the actual drawable texture dimensions because the view's reported `drawableSize` differed in the offscreen fixture; presentation point scaling is derived from drawable pixels and view points.

## Deviations from Plan

None — the implementation and verification remained within Task 2 scope. The drawable-dimension correction and queue-completion fence address behavior exposed by the planned fixture.

## Issues Encountered

- The first production routing run exposed a mismatch between `MTKView.drawableSize` (128×96) and the actual current drawable texture (64×48). The oversized spatial viewport was correctly rejected; routing and entry depth preparation were changed to use the actual drawable when available. The transition fixture then passed.
- The initial fixture checked asynchronous GPU completion after a fixed 20 ms run-loop pump. Evidence showed the requested step had been encoded exactly once (`stepCount=1`, `pendingSteps=0`, `encoded3DStepCount=1`) while completion had not yet arrived. A command-queue fence now makes the completion assertion deterministic.
- Inline code review found no unresolved critical or important issues. This was not independent-agent verification.

## User Setup Required

None — no external service configuration is required.

## Verification

```sh
python3 -m unittest Tests.Integration.test_inspection3d_state Tests.Integration.test_fluid3d.Fluid3DTests.test_inspection_routing Tests.Integration.test_fluid3d.Fluid3DTests.test_renderer_steps_and_inactivity Tests.Integration.test_fluid3d.Fluid3DTests.test_transitions_and_failures Tests.Integration.test_renderer_correctness Tests.Integration.test_educational_release
```

**PASS:** 10 tests, including the new production routing fixture, both existing renderer failure/step fixtures, and both established renderer harnesses.

```sh
xcodebuild -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

**PASS:** Fresh Mac and iOS Simulator builds succeeded; `git diff --check` passed. The iOS build emitted the existing iOS 26 `UIRequiresFullScreen` deprecation warning and simulator-placeholder version note.

## Next Phase Readiness

- Plan 08-03 / Wave 3 is complete; next is **08-04 / Wave 4** for native camera/slice controls and gesture routing.
- Later Phase 8 plans remain incomplete. No phase-level verification or completion was performed.
- INS-01, INS-02, INS-03, INS-04, and CTRL-08 remain pending; full-state independence, tracers, native controls, and the 08-09 human acceptance checkpoint are later work. Actual macOS 26 runtime and physical-device multitouch remain **NOT TESTED**.

---
*Phase: 08-spatial-inspection*
*Completed: 2026-11-14*

## Self-Check: PASSED

Both plan tasks and their acceptance criteria were checked. The state-scope harness, renderer routing/step/failure fixtures, both established renderer harnesses, fresh Mac/iOS builds, and whitespace check passed. No 2D solver or ABI changes were made; no later Phase 8 plan was started, and no user-facing Phase 8 requirement is marked complete.

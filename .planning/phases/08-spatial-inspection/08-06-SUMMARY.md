---
phase: 08-spatial-inspection
plan: "06"
subsystem: rendering
tags: [swift, metal, tracer-scheduling, depth-occlusion, appkit, evidence]

requires:
  - phase: 08-spatial-inspection
    provides: Production 64-cubed solver, spatial sheet, camera, and forward-RK2 tracer resources
provides:
  - Accepted-step renderer scheduling for hidden and no-drawable tracer evolution
  - Opaque-sheet depth-tested tracer discs and native Show Tracers control
  - Failure-context copy and fresh Free Play recovery for active 3D failures
  - Production GPU scheduling, occlusion, and presentation evidence
affects: [08-07, 08-08, 08-09]

tech-stack:
  added: []
  patterns:
    - Tracers advance after a validated solver encode and before step consumption/drawable acquisition
    - Presentation-only draws and visibility choices never control tracer evolution
    - Spatial fixtures share one inspection-contract reference, source inventory, and capture routing

key-files:
  created:
    - .planning/phases/08-spatial-inspection/08-06-REVIEW.md
  modified:
    - FluidDynamicsMetal.xcodeproj/project.pbxproj
    - Sources/Shared/Renderer.swift
    - Sources/Shared/FieldVisualization3D.swift
    - Sources/Shared/Shaders3D.metal
    - Sources/Shared/TracerSystem3D.swift
    - Sources/macOS/RenderViewController.swift
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
    - Tests/UI/macOS/HUDUITests.swift

key-decisions:
  - "An initial 3D preparation failure retains the existing usable 2D session."
  - "Active 3D failures and failed 3D Restart recover to fresh running Free Play while retaining Free Play preferences."
  - "Keep the 08-09 human-review checkpoint and leave all Phase 8 requirements pending."

patterns-established:
  - "A tracer image fixture must independently prove its probe ray intersects outside the sheet before checking visible pixels."
  - "Every spatial production fixture uses the inspection contract and its separately hashed source/capture inventory."

requirements-completed: []

duration: approximately 2h 30min
completed: 2026-11-14
---

# Phase 8 Plan 06: Renderer Tracers and Spatial UI Summary

**Passive tracers now advance exactly with accepted 3D renderer steps, render as depth-occluded discs, and are controlled through the native macOS inspection panel.**

## Performance

- **Duration:** Approximately 2 hours 30 minutes; exact start time was not recorded.
- **Completed:** 2026-11-14.
- **Tasks:** 2/2.

## Accomplishments

- Integrated tracer advancement into the production renderer after the 3D solver step has encoded successfully and before the logical step is consumed. Advancement is independent of checkbox visibility and drawable availability; presentation-only/paused draws do not advance tracers.
- Kept simulation, visualization, and tracer resources transactional. Initial 3D preparation failures retain the usable 2D session; active failures and failed 3D Restart recover to fresh running Free Play with retained Free Play preferences.
- Added instanced pale-cyan discs using the sheet’s camera transform and shared depth attachment. The opaque dye sheet occludes behind-sheet tracers in black and dyed regions; surviving marker fragments write depth, while the explicit orientation-guide overlay does not.
- Added the native **Show Tracers** checkbox between Slice and Camera, helper/factual copy, accessibility identity and help, keyboard focus routing, and Restart retention coverage.
- Distinguished initial preparation alerts from active-session failure alerts. Continue/Escape returns to the already recovered 2D Free Play state.
- Corrected the outside-footprint fixture to use an in-bounds marker and oblique camera whose independently projected ray lands outside the XY sheet. Corrected spatial evidence routing so `tracer-occlusion` uses the inspection contract, source inventory, and capture directory.
- Added the missing `TracerSystem3D.swift` source to the renderer state-test target.

## Task Commits

1. **Task 1: Schedule tracer evolution with renderer steps** — RED `761d647`; GREEN `075cc6a`.
2. **Task 1 test-target wiring follow-up** — `e775df7`.
3. **Task 2: Render depth-occluded tracers and native controls** — GREEN `26a37b6`.
4. Plan summary, review, and state tracking are recorded in the separate closeout commit.

## Verification

- Fast inspection state/reference checks: **2/2 passed**.
- Spatial fixture routing and occlusion-evidence unit checks: **2/2 passed**.
- Production GPU fixtures on Apple M3 Pro: **4/4 passed**:
  - `inspection-routing`: hidden advancement, nil-drawable presentation, paused pending steps, inspection retention/reset, and positive camera/image changes passed.
  - `tracer-evolution`: 512 exact seeds; 4,096 forward-RK2 position comparisons with maximum oracle error `2.5749206544745107e-08`; 27 wall/edge/corner probes; 28 affine-MAC probes; 48 production steps; three queued renderer commands; hidden/no-drawable advancement, paused immutability, and Restart checks passed.
  - `transitions-and-failures`: injected allocation, pipeline, reset, wrong-grid, tracer-allocation/reset/advance failures passed; recovery from all three 2D lessons reached running Free Play with retained preferences, and failed-Restart retry succeeded.
  - `tracer-occlusion`: visible/hidden checks in black and dyed regions, outside-footprint visibility, opposite-side occlusion, circular edge-on discs, exact color, opaque sheet, and discarded disc corners passed. Measured diameter was 2 px / 2 pt at 1× and 6 px / 3 pt at 2×, within the registered size tolerance. Captures are under `.build/inspection3d-evidence/`; reports are under `.build/fluid3d-evidence/`.
- Fresh Mac Debug and generic iOS Simulator Debug builds: **passed**.
- Mac state tests: **25/25 passed**.
- Focused macOS spatial controls, layout, gesture isolation, tracer visibility/Restart, and failure/retry UI tests: **5/5 passed**.
- Existing 2D renderer and educational production regressions: **6/6 passed**.
- Fresh evidence provenance checks for all four Wave 6 production fixtures: source hashes, reference hashes/contracts, metrics, and captures **passed**.
- `git diff --check`: **passed**.

The iOS build emitted the existing `UIRequiresFullScreen` deprecation warning and skipped App Intents metadata extraction because the target has no AppIntents dependency. Neither warning failed the build.

## Inline Review

The scoped inline review found no unresolved issues. See
`08-06-REVIEW.md`. The earlier grouped-run `tracer-evolution` exit `-9` was not
reproduced when run independently; no environmental cause is asserted.

## Scope Limits and Next Plan Readiness

- Plan 08-06 / Wave 6 is complete; Plan 08-07 / Wave 7 is next.
- Plans 08-07 and 08-08 remain incomplete. Plan 08-09 remains the human visual,
  accessibility, and input-review checkpoint; automated UI tests are not a
  substitute for that review.
- No Phase 8 requirement is complete, and no phase-level verification ran.
  `INS-01`, `INS-02`, `INS-03`, `INS-04`, and `CTRL-08` remain pending.
- Actual macOS 26 runtime behavior, VoiceOver review, physical input direction/
  feel review, and physical-device checks are not claimed as tested.

---
*Phase: 08-spatial-inspection*
*Completed: 2026-11-14*

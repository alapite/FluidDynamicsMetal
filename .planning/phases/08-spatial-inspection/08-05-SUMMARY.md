---
phase: 08-spatial-inspection
plan: "05"
subsystem: simulation
tags: [swift, metal, passive-tracers, forward-rk2, mac-sampling, status-guard]

requires:
  - phase: 08-spatial-inspection
    provides: Production 64-cubed MAC velocity fields and per-submission projection status
provides:
  - Deterministic 512-marker reset/storage inventory
  - Guarded forward RK2 tracer advancement from projected u/v/w
  - Production GPU evidence against independent Double expectations
affects: [08-06, 08-07, 08-08, 08-09]

tech-stack:
  added: []
  patterns:
    - Each in-place SIMD4 marker is advanced by one GPU thread using production MAC sampling
    - Per-submission solver status is bound read-only in command order, without CPU readback

key-files:
  created:
    - Sources/Shared/TracerSystem3D.swift
  modified:
    - Sources/Shared/PressureProjection3D.swift
    - Sources/Shared/Shaders3D.metal
    - Tests/Integration/inspection3d_reference.swift
    - Tests/Integration/test_inspection3d_reference.py
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
    - FluidDynamicsMetal.xcodeproj/project.pbxproj

key-decisions:
  - "Keep one 8,192-byte in-place position buffer; each kernel lane owns exactly one marker and no tracer pass writes fluid state."
  - "Read the returned solver status buffer through a narrow device-validated binding and guard failure, nonconvergence, cap hits, and malformed status on GPU."
  - "Use the independent Double inspection oracle for constant-field forward RK2, affine MAC, and wall/edge/corner expectations."

patterns-established:
  - "Tracer advancement consumes the simulation's current ping generations after projection swaps, in the same ordered command stream."
  - "A fixture using inspection expectations must validate and hash the inspection manifest/source inventory rather than the historical solver reference."

requirements-completed: []

duration: approximately 56min
completed: 2026-11-14
---

# Phase 8 Plan 05: Passive Tracer Evolution Summary

**Production passive tracers now reset to an exact full-volume 8-cubed seed lattice and advance with guarded forward RK2 from the newly projected three-component MAC velocity.**

## Performance

- **Duration:** Approximately 56 minutes.
- **Started:** 2026-11-14T18:09:32Z (Task 1 RED commit; exact session-start time not captured).
- **Completed:** 2026-11-14T19:05:30Z.
- **Tasks:** 2/2.
- **Files modified:** 8 implementation, project, and test files.

## Accomplishments

- Created checked tracer storage with 512 unique, deterministic, i-fastest interior seeds; production readback verified all 2,048 SIMD4 lane values, byte-identical repeated reset, 16-byte stride/alignment, and the exact 8,192-byte position allocation.
- Added production forward RK2 advancement using `simulation.u/v/w.ping`, the configured `dt`, and the shared reflected MAC `sampleVelocity` implementation. Per-submission status is bound as a const shader resource in command order; the GPU fixture verified that current and prior-session projection failures leave marker bytes unchanged. The kernel predicate also requires finite status, convergence, and no cap hit before writing.
- Extended the independent Double oracle and actual Metal fixture to cover eight signed/combined velocity fields (4,096 compared positions), 27 wall/edge/corner probes, 28 affine staggered-MAC probes, three queued submissions, no-fluid-feedback snapshots, and 48 accepted production solver/tracer steps.

## Task Commits

1. **Task 1: Add repeatable full-volume seeding and checked tracer storage** — RED `ca077c9`; GREEN `10d39a5`.
2. **Task 2: Advance with forward RK2 and production solver status guards** — RED `c48060d`; evidence-routing regression RED `3532d8e`; GREEN `346c096`.

Plan summary and tracking metadata are recorded in the separate plan closeout commit.

## Files Created/Modified

- `Sources/Shared/TracerSystem3D.swift` — checked position storage, deterministic reset, readback diagnostics, and guarded advance encoding.
- `Sources/Shared/PressureProjection3D.swift` — narrow device-validated read-only `StatusSlot` encoder binding.
- `Sources/Shared/Shaders3D.metal` — forward RK2 tracer kernel using production reflected MAC sampling and solver-status guards.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj` — shared tracer source membership in both application targets.
- `Tests/Integration/inspection3d_reference.swift` — independent Double forward-RK2, affine-MAC, and boundary expectation export.
- `Tests/Integration/test_inspection3d_reference.py` — independent expectation validation.
- `Tests/Integration/test_fluid3d.swift` — reset, oracle comparison, queued-status, failure-guard, no-feedback, and 48-step GPU fixture.
- `Tests/Integration/test_fluid3d.py` — fixture execution, evidence validation, and inspection-manifest/source routing.

## Decisions Made

- One in-place position buffer is sufficient because each dispatched thread reads and writes only its own marker; no scratch or ping/pong position allocation is needed.
- The status buffer remains hidden behind `StatusSlot`; the tracer system receives no mutable status state and performs no premature CPU diagnostic read.
- The unit-cube domain is validated at encoding time. Advancement remains a step-owner responsibility and is not attached to render or visibility updates in this plan.

## Deviations from Plan

No production-scope deviation. Inline review found that the evidence validator still assumed every fixture used the historical fluid reference manifest. The tracer fixture now resolves the pinned inspection manifest and its spatial source inventory, with a regression test for that routing.

## Issues Encountered

- The initial Task 2 RED compile exposed the expected missing `encodeAdvance` API. Test-harness compilation issues were corrected before the final RED run, which then failed only at the missing feature.
- The evidence-manifest routing mismatch was corrected before the GREEN commit; the new routing regression passes.

## User Setup Required

None.

## Verification

- Independent oracle, state, evidence-schema, status-read-only, and fixture-routing checks: **8/8 tests passed** in the final focused command.
- Production GPU fixtures: `tracer-evolution`, `advection-boundaries`, and `projection` **3/3 passed** on Apple M3 Pro. Tracer evidence reports 4,096 forward-RK2 position comparisons, maximum constant-field oracle error `2.5749206544745107e-08`, 27 boundary probes, 28 affine probes, exact reset, current/prior failure guards, three queued submissions, unchanged fluid snapshots, and 48 finite bounded production advances. Evidence: `.build/fluid3d-evidence/tracer-evolution.json`.
- Fresh Mac Debug and iOS Simulator Debug builds: **passed**.
- Mac HUD UI suite via `xcodebuild test`: **19/19 tests passed, 0 failures**.
- `git diff --check`: **passed** before metadata closeout.

## Self-Check: PASSED

- `Sources/Shared/TracerSystem3D.swift` exists, and all 08-05 task and closeout commits are present.
- Fresh post-wave Mac and iOS Simulator builds passed; the focused six-test acceptance run passed, including tracer evolution, read-only status, advection/boundaries, and projection.
- `git diff --check 163cd40..HEAD` passed. The broader integration discovery run exceeded the 300-second post-wave gate timeout, so that run is inconclusive and is not reported as a full-suite pass.

## Next Plan Readiness

- Plan 08-05 / Wave 5 is complete; Plan 08-06 / Wave 6 is next. It can integrate accepted-step scheduling, hidden advancement, visibility, and sheet occlusion using this advancement API.
- Plan 08-07 complete-state comparisons, Plan 08-08 fresh evidence/usage, and Plan 08-09 human visual/accessibility/input review remain outstanding.
- Phase 8 requirements **INS-01, INS-02, INS-03, INS-04, and CTRL-08 remain pending**. This plan establishes tracer reset and advancement only; it does not complete renderer integration, presentation-independent equal-step acceptance, or the human checkpoint.

---
*Phase: 08-spatial-inspection*
*Completed: 2026-11-14*

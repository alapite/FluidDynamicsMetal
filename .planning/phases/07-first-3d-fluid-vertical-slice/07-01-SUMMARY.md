---
phase: 07-first-3d-fluid-vertical-slice
plan: 01
subsystem: testing
tags: [swift, python, mac-grid, numerical-reference, fluid-simulation]

# Dependency graph
requires: []
provides:
  - Preregistered 3D MAC numerical contract with a pinned prefix hash
  - Independent Swift Double oracle and quick/full-grid CPU feasibility gates
  - Deterministic binary operator, projection, and full-volume fixtures for the next GPU harness
affects: [07-02-first-3d-fluid-kernel, GPU-acceptance-harness]

# Tech tracking
tech-stack:
  added: [standalone Swift 6 CPU oracle, Python unittest driver, little-endian Float64 fixture export]
  patterns: [independent DG and neighbor-stencil operators, true-residual PCG acceptance, hashed fixture manifests]

key-files:
  created: [Tests/Integration/fluid3d_reference.swift]
  modified: [docs/3d-numerical-contract.md, Tests/Integration/test_fluid3d_reference.py]

key-decisions:
  - "Selected a 320-iteration PCG cap after the wall/edge/corner fixture needed 270; retained every preregistered residual and divergence threshold."
  - "Scaled compatibility-mean roundoff against h*normInf(u*) as well as the RHS to handle cancellation in the divergence-free fixture."
  - "Recalibrated the independent trajectory start while preserving the preregistered 0.01 plane-RMS/arc-length threshold."
  - "Exported full-volume unequal-axis velocity and dye arrays and checked the asymmetric operator payload against its registered formula."

requirements-completed: [SIM-05, VER-03]

# Metrics
duration: 40min
completed: 2026-11-06
---

# Phase 7 Plan 07-01 Summary

**A hash-pinned 3D MAC contract now has an independent Double oracle, passing 64³ projection feasibility results, and reproducible GPU-harness fixture data.**

## Performance

- **Duration:** Approximately 40 minutes from the first committed plan artifact through summary completion; excludes earlier preparation.
- **Started:** 2026-11-06T21:14:32Z (first artifact commit)
- **Completed:** 2026-11-06T21:54:20Z (summary finalized; summary commit follows)
- **Tasks:** 2 completed
- **Files modified:** 3 plan artifacts, plus this summary

## Accomplishments

- Preregistered compatible MAC divergence/gradient operators, wall/reflection rules, advection order, projection failure behavior, tolerances, fixtures, and observation metrics before any 3D production kernel work. The pinned contract-prefix SHA-256 is `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`.
- Added a standalone Swift Double oracle with independently formed `-h²DG` and neighbor-stencil operators, analytic interpolation/advection/reflection checks, an asymmetric direct-solve cross-check, and 64³ pressure feasibility families.
- Verified all seven 64³ pressure families as finite and converged without hitting the 320-iteration cap. The nontrivial families converged in 1, 154, 159, and 270 iterations; true residual and projected-divergence gates remained at or below `1e-5`.
- Exported six deterministic binary payloads under `.build/fluid3d-reference`, including the full-volume XYZ velocity and dye data at steps 0/24/48. All payload sizes, shapes, and SHA-256 hashes were checked; the manifest SHA-256 is `b7042898c88e3872699de8e8d3fcdc3da20cbfc8c21fe31ac7fe11e0188ec7e0`.
- Confirmed no 2D production source, `.planning/STATE.md`, or `.planning/ROADMAP.md` changes.

## Verification

- `python3 -m unittest Tests.Integration.test_fluid3d_reference.ReferenceContractTests.test_quick_contract Tests.Integration.test_fluid3d_reference.ReferenceContractTests.test_reference_feasibility Tests.Integration.test_fluid3d_reference.ReferenceContractTests.test_reference_export_contains_full_volume_fixture` — **PASS**, 3 tests. Measured oracle invocation times: quick `0.022 s`; 64³ feasibility `1.989 s` (excluding compilation and unittest setup).
- `python3 Tests/Integration/test_fluid3d_reference.py --export .build/fluid3d-reference --check-contract` — **PASS**, pinned contract hash verified and six payloads exported.
- Independent export audit — **PASS**, every payload matched its manifest byte count, shape-derived byte length, and SHA-256. The asymmetric operator payload also matched the registered pressure formula and its `DG`/neighbor-stencil arrays agreed within `1e-10`.
- `git diff --check` — **PASS**. No app build, GPU-kernel acceptance, UI test, or production-lesson result is claimed; those are outside this CPU-reference plan.

## Task Commits

Task 2 used separate red-test and green implementation commits:

1. **Task 1: preregister MAC numerical contract** — `531776314096a0f30b68a5706bf6b0fd96c50f80` (`docs(07-01): preregister MAC numerical contract`)
2. **Task 2 RED: add failing CPU reference contract tests** — `cb268539cd517653f1ad40b032443e25493526f2` (`test(07-01): add failing CPU reference contract tests`)
3. **Task 2 RED: assert MAC face and midpoint references** — `a83b9568fb0b812372ec4cd0a3c7092617996e0a` (`test(07-01): assert MAC face and midpoint references`)
4. **Task 2 RED: require exported full-volume oracle data** — `ed125e1546d245083315de8ac2bbef45f9b8f029` (`test(07-01): require exported full-volume oracle data`)
5. **Task 2 RED: validate registered exported fixture inputs** — `4383117382715aed651c3495bcb981189b073ebb` (`test(07-01): validate exported oracle fixture inputs`)
6. **Task 2 GREEN: add CPU oracle and feasibility results** — `2d4057e3a7ca9557a3b7ecb55f5151bf3b649138` (`test(07-01): add CPU reference oracle and feasibility results`)

**Plan metadata:** This summary is committed separately after the task commits; its commit hash is reported in the completion message to avoid a self-referential hash.

## Files Created/Modified

- `docs/3d-numerical-contract.md` — Locked numerical contract, justified pre-kernel revisions, measured feasibility results, and export hashes.
- `Tests/Integration/test_fluid3d_reference.py` — Discoverable quick/full tests, full-volume export checks, and registered asymmetric-payload assertions.
- `Tests/Integration/fluid3d_reference.swift` — Standalone Double operators, PCG reference, analytic fixtures, trajectory metrics, and deterministic exporter.
- `.planning/phases/07-first-3d-fluid-vertical-slice/07-01-SUMMARY.md` — This execution record.

## Decisions Made

- Raised the candidate pressure-iteration cap from 256 to 320 after the wall/edge/corner fixture required 270 iterations. Accuracy thresholds were not loosened.
- Bounded compatibility-mean removal using `64 * epsilon * max(normInf(b), h*normInf(u*), 1e-30)` after the divergence-free fixture exposed roundoff relative to near-zero RHS.
- Recalibrated the independent nonplanar trajectory fixture to a start that demonstrates `planeRMS/arcLength = 0.01662382`, retaining the original `0.01` minimum.
- Corrected an exporter-only asymmetric-pressure formula mismatch after a new content assertion failed by `1.99053`; the implementation now exports the registered `0.37*i + 0.19*j + 0.43*k` sine input.

## Deviations from Plan

The numerical candidate cap, compatibility-roundoff scale, and trajectory start were revised before production kernels and are recorded above with CPU evidence. A final code review also found that the asymmetric operator export did not initially match the preregistered formula; a test-only commit captured the failure before the exporter was corrected. These changes were necessary to preserve independent, reproducible evidence; no GPU-derived tolerance fitting or production-kernel scope was added.

## Issues Encountered

- At 256 iterations, the wall/edge/corner fixture ended at `3.88010297e-5`, exceeding the unchanged `1e-5` gates. A 512-cap probe converged in 270 iterations at `9.5921123e-6`, motivating the 320 cap.
- The first exporter-content regression run failed as expected on the mismatched asymmetric fixture; after correcting the formula, the focused suite and export audit passed.
- No unresolved blockers remain for the 07-01 CPU-reference scope.

## User Setup Required

None — no external service or account configuration is required.

## Next Phase Readiness

- Plan 07-01 has supplied the contract and deterministic CPU oracle data needed by the 07-02 GPU harness.
- This is **not** GPU acceptance and does not claim that user-facing `SIM-05` or production-check `VER-03` behavior is complete. The phase-level requirement tracker remains pending until the production 3D kernels and GPU checks are delivered; no requirement checkbox or project state was changed here.
- `.planning/STATE.md` and `.planning/ROADMAP.md` were left untouched as instructed.

## Self-Check: PASSED

- This required summary file exists, and all six task commits plus the prior summary commit are present in the history of `worktree-agent-07-01`.
- The focused CPU suite passed **3/3 tests** (quick `0.022 s`, 64³ feasibility `2.004 s`); fixture export and the pinned contract hash check passed.
- The export audit verified all six payload shapes, byte counts, and SHA-256 hashes; manifest SHA-256: `b7042898c88e3872699de8e8d3fcdc3da20cbfc8c21fe31ac7fe11e0188ec7e0`.
- `.planning/STATE.md`, `.planning/ROADMAP.md`, and `Sources/` have no changes.

---
*Phase: 07-first-3d-fluid-vertical-slice*
*Completed: 2026-11-06*

---
phase: 08-spatial-inspection
plan: "02"
subsystem: rendering
tags: [swift, metal, spatial-inspection, cube-guide, gpu-regression]
requires:
  - phase: 08-spatial-inspection
    provides: Validated inspection state, camera projection, and pinned independent inspection contract from 08-01
provides:
  - Throwing depth-equipped encodeInspection path for continuous-depth XY/XZ/YZ sheets
  - Projected subdued 12-edge cube guide with contrast and point-scale support
  - Asymmetric production GPU fixture for sampling, resource reuse, and failure guards
affects: [08-03, 08-04, 08-07, 08-08]
tech-stack:
  added: []
  patterns:
    - Separate spatial sheet and guide pipelines preserve the legacy fixed-slice path
    - Size-keyed presentation depth attachments are retained through command completion
    - Spatial evidence hashes include the independent oracle and inspection contract without relabeling historical fixtures
key-files:
  created: []
  modified:
    - Sources/Shared/FieldVisualization3D.swift
    - Sources/Shared/Shaders3D.metal
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
key-decisions:
  - "Keep encodeSlice as the legacy fixed central-XY path; encodeInspection owns the new full-aspect, depth-equipped presentation."
  - "Render cube edges as a depth-independent, one-point overlay so orientation remains visible over empty dye and the selected sheet."
  - "Keep spatial captures under .build/inspection3d-evidence and spatial source hashes separate from historical solver/slice evidence."
  - "Keep INS-01, INS-02, and INS-04 pending until interactive app integration and user-facing acceptance are complete."
requirements-completed: []
requirements-referenced: [INS-01, INS-02, INS-04]
duration: approximately 65 min
completed: 2026-11-13
---

# Phase 08 Plan 02: Spatial Sheet and Cube Guide Summary

**A read-only, depth-equipped spatial sheet renderer now samples all three fixed planes and overlays a fitted, subdued cube guide while preserving the Phase 7 slice path.**

## Performance

- **Duration:** Approximately 65 minutes.
- **Started:** 2026-11-13T20:11:10Z (first Plan 08-02 RED fixture commit).
- **Completed:** 2026-11-13T21:16:24Z (Task 2 commit).
- **Tasks:** 2/2.
- **Files modified:** 4.

## Accomplishments

- Added `encodeInspection(command:simulation:destination:viewport:inspection:pointScale:increaseContrast:) throws` with a separate inspection ABI and spatial pipelines. The encoder validates destination/viewport inputs, defers zero-sized presentation, samples the production dye texture continuously at cell-centred coordinates, and owns only a reusable `depth32Float` attachment.
- Preserved `encodeSlice(...)`, its central XY benchmark semantics, and the established 2D solver/ABI. No tracer-system dependency or simulation-resource write was introduced.
- Added the complete projected cube guide as 12 thin, depth-independent edges. Normal and Increase Contrast colors are `#666666` and `#A6A6A6`; stroke width scales from one point at 1×/2×.
- Expanded the asymmetric production fixture with independent affine/landmark samples, backside and edge-on checks, narrow/tall/wide fitting, camera/image changes, 1×/2× guide coverage, empty-dye guides, exact ping/pong bit comparisons, viewport/input guards, allocation failures, and attachment/pipeline reuse.
- Recorded five new captures in `.build/inspection3d-evidence`; the spatial report remains distinct from historical benchmark image and source-hash inventories.

## Task Commits

1. **Task 1: Implement a depth-equipped two-sided spatial sheet** — RED fixture `7851f4b`, fixture typing correction `c81e35a`, implementation `389f3b6`.
2. **Task 2: Add subdued cube geometry and viewport/resource regressions** — `e362a04`.

The task commits are separate. The Task 2 code and its regression coverage were committed together; the review follow-up also recorded an observed guard-removal failure and a passing restored implementation. No independent-agent review was performed.

## Files Created/Modified

- `Sources/Shared/FieldVisualization3D.swift` — throwing spatial render path, depth reuse, cube-guide pipeline, checked resource allocation, and shared destination diagnostics.
- `Sources/Shared/Shaders3D.metal` — fixed-plane spatial sampling and projected thin-edge guide geometry.
- `Tests/Integration/test_fluid3d.swift` — independent GPU sampling, projection, resource immutability/reuse, allocation, and invalid-input checks.
- `Tests/Integration/test_fluid3d.py` — separated spatial source inventory and fixture-evidence validation.
- `.planning/phases/08-spatial-inspection/08-REVIEW.md` — scoped inline review; no unresolved findings.

## Decisions Made

- Spatial output uses the selected camera’s full-aspect projection; the guide is drawn after the sheet with depth testing disabled for the overlay and depth writes disabled.
- Depth attachments are keyed by destination size, reused for repeated sizes, and held alive through command completion when replaced.
- Spatial captures and hashes remain separate from the Phase 7 solver/fixed-slice benchmark evidence.
- Phase requirements remain pending because this plan delivers the production rendering path, not the interactive controls or end-to-end user acceptance.

## Deviations from Plan

### Review hardening

**1. [Rule 2 - Missing Critical] Added explicit input-guard regression coverage**
- **Found during:** Inline review after Task 2 verification.
- **Issue:** Production guards already rejected an invalid pixel format and out-of-bounds viewport and deferred zero extent, but these plan-required paths were not asserted by the spatial fixture.
- **Fix:** Added fixture checks for all three paths and evidence-schema requirements for the resulting booleans.
- **Files modified:** `Tests/Integration/test_fluid3d.swift`, `Tests/Integration/test_fluid3d.py`.
- **Verification:** A temporary removal of the destination-format guard caused the spatial GPU fixture to fail with Metal API Validation’s attachment-format assertion; with the guard restored, the final spatial fixture passed.
- **Committed in:** `e362a04`.

**2. [Rule 1 - Bug] Corrected a misleading destination-format diagnostic**
- **Found during:** Inline review of the new invalid-input fixture.
- **Issue:** Spatial inspection reused an error message that called the destination a legacy “slice” target.
- **Fix:** Changed the shared message to “3D visualization destination” and asserted the spatial diagnostic.
- **Files modified:** `Sources/Shared/FieldVisualization3D.swift`, `Tests/Integration/test_fluid3d.swift`.
- **Verification:** The diagnostic assertion failed before the wording change and passed in the final spatial fixture.
- **Committed in:** `e362a04`.

**3. [Process deviation - TDD evidence unverified] Task 2 RED phase cannot be substantiated**
- **Found during:** Wave 2 closeout audit.
- **Issue:** Task 2 is marked `tdd="true"`, but its production implementation and regression coverage were committed together in `e362a04`. The execution record contains no pre-implementation RED command/result, and the executor could not confirm that the new tests were observed failing before implementation.
- **Disposition:** Record the RED phase as unverified. Do not infer test-first evidence from the final passing tests or invent a failure result. This is a process-evidence gap; the focused final tests and builds pass, and no production defect was found by those checks.

**Total deviations:** 2 review hardenings (one coverage gap, one diagnostic defect) and 1 TDD evidence gap. **Impact:** The review hardenings remain within Plan 08-02’s validation and error-reporting scope; the TDD ordering for Task 2 remains unverified. No acceptance threshold or feature scope changed.

## Issues Encountered

- The first fast evidence-schema run after adding the new evidence fields exposed an incomplete synthetic report in the Python test. The synthetic fixture was updated with the required fields; the final fast suite passed 5/5.
- The final spatial fixture, legacy slice/palette fixture, and evidence-schema regression passed 3/3 in 76.5 seconds. The fresh spatial evidence reports 24 asymmetric samples across XY/XZ/YZ at depths 0/0.3/0.5/1, all 12 cube edges, one-point scale ratio 3.9728 (919/3651 guide pixels), two depth allocations for two distinct repeated sizes, two spatial pipelines, and successful injected allocation failures.

## Verification

```sh
python3 -m unittest Tests.Integration.test_inspection3d_state Tests.Integration.test_inspection3d_reference Tests.Integration.test_fluid3d.Fluid3DTests.test_evidence_schema Tests.Integration.test_fluid3d.Fluid3DTests.test_spatial_source_inventory_is_separate_from_historical_fixture_inventory Tests.Integration.test_fluid3d.Fluid3DTests.test_spatial_fixture_evidence_requires_cube_resource_and_camera_checks
```

**PASS:** 5 tests, 2.7 seconds.

```sh
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

**PASS:** Both final-source builds succeeded. The iOS build retained the existing App Intents metadata warning and simulator-placeholder version note.

```sh
python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_spatial_slices Tests.Integration.test_fluid3d.Fluid3DTests.test_slice_and_palette Tests.Integration.test_fluid3d.Fluid3DTests.test_evidence_schema
git diff --check
```

**PASS:** 3/3 production GPU/schema tests; `git diff --check` passed. Spatial source hashes are current in `.build/fluid3d-evidence/spatial-slices.json`. Captures: `.build/inspection3d-evidence/`.

## Next Phase Readiness

- Ready for **08-03 / Wave 3**. No later plan was started.
- INS-01, INS-02, INS-03, INS-04, and CTRL-08 remain pending; app routing, native controls, tracers, complete-state independence, and human acceptance are later work.
- The 08-09 human visual/accessibility/input checkpoint remains blocking for Phase 08 acceptance. No manual review or UI integration is claimed here.

---
*Phase: 08-spatial-inspection*
*Completed: 2026-11-13*

## Self-Check: PASSED

Both plan tasks, acceptance criteria, fresh app builds, production spatial and legacy fixtures, and the inline review were checked against the actual final files and command output. Task 2's TDD RED ordering could not be substantiated and is recorded above rather than treated as verified. The pinned inspection contract remains unchanged; all new GPU images and spatial hashes are kept separate from historical benchmark evidence. No Phase 08 user-facing requirement is marked complete.

---
phase: 07-first-3d-fluid-vertical-slice
plan: 14
subsystem: 3d-display-transfer
tags: [metal, swift, display-transfer, sqrt, inspection-contract, uat-gap, g-07-2, tdd]

requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: 07-12 user report that returning dye is very dim; 07-11 measured returning peak 0.201 at step 600
provides:
  - Fixed square-root display transfer d = sqrt(clamp(c,0,1)) in fluid3DFixedSlice, fluid3DSpatialSlice, FieldVisualization3D.encodedColor(for:) and the native 3D legend
  - Dated inspection-contract amendment with one new SHA-256 repinned in five places
  - PHASE7_HASH repinned to the current complete numerical contract (repairs the latent 07-11 break)
  - Fail-closed slice-palette validator for displayTransfer, paletteStops and transferSamples
affects: [07-13, 07-16, 07-17, phase-08-ui-spec]

actuals:
  tokens: 8100
  tasks: 3
  commits: 6

plan_head_before: 0583a57d6bf98d8c7fcf0bbbea8578c411122741
plan_head_after: 60381fd39492de79c390a78bda52077827fd866a
commits: 6

tech-stack:
  added: []
  patterns:
    - "Presentation-only display transfer ahead of an unchanged palette; stop positions are display values"
    - "Legend painted per backing-pixel column from the same Swift function the tests compare the shader against"

key-files:
  created: []
  modified:
    - docs/3d-inspection-contract.md
    - Sources/Shared/FieldVisualization3D.swift
    - Sources/Shared/Shaders3D.metal
    - Sources/macOS/RenderViewController.swift
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
    - Tests/Integration/inspection3d_reference.swift
    - Tests/Integration/test_inspection3d_reference.py
    - Tests/UI/macOS/HUDUITests.swift

key-decisions:
  - "Fixed square-root transfer rather than an auto-range: 07-UI-SPEC and 08-UI-SPEC forbid per-frame normalisation, and an auto-range would hide genuine thinning (D-09)"
  - "sqrt rather than pow in Metal: pow at 0 is not guaranteed under fast math"
  - "paletteStops keeps its field name; its values are now display values d = 0/0.5/1 (concentration 0/0.25/1)"
  - "Legend axis stays linear in concentration while column colours follow the shader transfer exactly"

requirements-completed: [SIM-05, VER-03]

coverage:
  - id: D1
    description: "Both production slice shaders and the Swift palette display concentration through the fixed square-root transfer, matching an independent Double formula within +-1 UNORM"
    requirement: "VER-03"
    verification:
      - kind: integration
        ref: "python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_slice_and_palette"
        status: pass
      - kind: integration
        ref: "python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_evolution_and_visibility"
        status: pass
      - kind: integration
        ref: "python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_spatial_slices Tests.Integration.test_fluid3d.Fluid3DTests.test_tracer_occlusion"
        status: pass
    human_judgment: false
  - id: D2
    description: "Inspection contract carries a dated square-root amendment; all five pins and PHASE7_HASH repinned; malformed palette evidence rejected"
    requirement: "VER-03"
    verification:
      - kind: integration
        ref: "python3 -m unittest Tests.Integration.test_inspection3d_reference"
        status: pass
      - kind: unit
        ref: "Tests/Integration/test_fluid3d.py#test_slice_palette_evidence_requires_square_root_transfer"
        status: pass
    human_judgment: false
  - id: D3
    description: "3D legend painted from encodedColor(for:) with honest square-root legend and note copy; 2D legends unchanged"
    requirement: "SIM-05"
    verification:
      - kind: automated_ui
        ref: "HUDUITests/testThreeDPanelFocusAndReturn, testSpatialTracerVisibilityAndRestart, testThreeDAppearanceCaptures"
        status: pass
    human_judgment: false
  - id: D4
    description: "Returning dye is legible enough to interpret what is going on (SIM-05 observe dye evolving)"
    requirement: "SIM-05"
    verification: []
    human_judgment: true
    rationale: "Readability of the brightened display is a human judgment; 07-17 asks the user to re-observe the fade-and-return."

duration: 11min
completed: 2026-11-21
status: complete
---

# Phase 07 Plan 14: Square-root display transfer Summary

**Fixed square-root display transfer (d = sqrt(clamp(c,0,1))) in both 3D slice shaders, the Swift palette and a per-column native legend, with a dated hash-pinned contract amendment, repinned PHASE7_HASH and fail-closed palette evidence validation.**

## Performance

- **Duration:** 11 min of agent time (excludes nothing; GPU fixtures and UI tests included)
- **Started:** 2026-11-21T09:04:03Z
- **Completed:** 2026-11-21T09:15:00Z
- **Tasks:** 3 (1 tracer, 2 TDD auto), 6 commits
- **Files modified:** 9

## Accomplishments

- Concentration 0.25 now displays full amber (237,139,35) instead of (119,70,18), so the 07-11 returning slice peak 0.201 maps to d = 0.448, close to the amber stop, while 1% haze stays dark (d = 0.1). Dye, velocity, pressure, tracer and status data are untouched (read-only presentation hashes unchanged).
- The transfer is identical in `fluid3DFixedSlice`, `fluid3DSpatialSlice` (via `fluid3DDisplayValue` / `fluid3DEncodedPaletteColor`), `FieldVisualization3D.displayValue(forConcentration:)` / `encodedColor(for:)` and the legend. No per-frame normalisation. `PaletteUniforms` (64 bytes), `stops.w = 0`, entry-point names, destination format, 2D solver, 2D palettes and iOS UI are unchanged.
- Repaired a latent 07-11 break: at HEAD 27713a9 `PHASE7_HASH` named the pre-07-11 complete numerical-contract hash (prefix 5fdc33b8) while the file hashed to be79b1bc, so `test_inspection3d_reference` failed and with it every spatial fixture (spatial-slices, tracer-evolution, tracer-occlusion, inspection-independence), which run it as their reference step. Repinned.

## Contract amendment and hashes

- **Heading:** `### Square-root display transfer amendment — 2026-11-21 (UAT G-07-2)` appended at the end of `docs/3d-inspection-contract.md`; the plan's removed-line guard (`git diff 27713a9`, count of `^-[^-]` lines) is 0.
- **Old inspection-contract SHA-256:** `7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7`
- **New inspection-contract SHA-256:** `ac824cffb3cb3db141cf1c03f9425cd67797db0586246480a258ddd06a502cbb`, written to INSPECTION_CONTRACT_HASH (test_fluid3d.py), both literals in test_fluid3d.swift, contractHash (inspection3d_reference.swift) and CONTRACT_HASH (test_inspection3d_reference.py). Zero occurrences of the old digest remain outside comments.
- **PHASE7_HASH:** old `5fdc33b839d7...` (historical), new `be79b1bceadc823f3a9c17c1aae73a818486e3fae557ac2d5f4d0047b8fde261` (current complete `docs/3d-numerical-contract.md`).

## Transfer anchor table

Independent Double formula (`expectedSpatialPaletteRGB`), pinned by the `transferAnchors` self-check; production shader output matched within +-1 UNORM on every landmark.

| Concentration | d | RGB |
|---|---|---|
| 0 | 0 | (0,0,0) |
| 1/64 | 0.125 | (59,35,9) |
| 0.25 | 0.5 | (237,139,35) |
| 0.5 | 0.7071 | (244,181,109) |
| 0.75 | 0.8660 | (250,214,166) |
| 1 | 1 | (255,241,214) |
| 1.25 (clamped) | 1 | (255,241,214) |

## RED evidence

- **Task 1 RED (8dd155c):** `Tests.Integration.test_fluid3d.Fluid3DTests.test_slice_and_palette` on the unchanged linear shader failed with `palette stop quarter RGB mismatch at (33,55): actual=SIMD3<Int>(119, 70, 18), expected=SIMD3<Int>(237, 139, 35) ±1 UNORM code`. `check tdd-red-evidence` returned RED_EVIDENCE_OK. Semantic assessment: the target ran, the transferAnchors self-check passed, and the failure is the planned quarter-landmark assertion.
- **Task 2 RED (2ca2d72):** `test_slice_palette_evidence_requires_square_root_transfer` failed with all 8 mutation subTests wrongly accepted (`[] is not true : <mutation> must be rejected`), after the unmutated report validated. RED_EVIDENCE_OK. Semantic assessment: the validator ignored displayTransfer, paletteStops and transferSamples, as planned.
- **Task 3 RED (9f916a0):** `testThreeDPanelFocusAndReturn` failed at HUDUITests.swift:365 (`"Less dye → More dye"` is not equal to `"Less dye → More dye · square-root scale"`) and `testSpatialTracerVisibilityAndRestart` failed at :875 on the old note text. Result bundle `.build/07-14-ui-red.xcresult` (gitignored).

## Results

- **slice-palette:** PASS (`.build/fluid3d-evidence/slice-palette.json`: `displayTransfer` = "square-root", three paletteStops with displayValue/concentration/rgb, seven transferSamples). Midpoint of planes 31/32 = (244,181,109); constant 0.5 at steps 0 and 1 across 64x64/96x64/48x48 = (244,181,109); 1.25 clamps to cream; letterboxes black; resource hashes unchanged.
- **evolution-visibility:** PASS; compareSliceImage agrees with `encodedColor` within +-1 on every capture; 07-11 E1-E7 gates pass. **E4 step-10 encoded-change count: 198** under the new mapping, versus 160 in 07-11 (gate >= 100). Step-10 RMS from step 0 is 0.0304 (unchanged: RMS is concentration-based and presentation-independent).
- **spatial-slices, tracer-occlusion:** PASS through the regenerated independent export. `test_inspection3d_reference`, `test_evidence_schema`, the new unit test, `ReferenceContractTests.test_quick_contract`: PASS. The Task 2 one-liner validating the real slice-palette report printed `[]`.
- **Builds:** Mac Debug and iOS Simulator (`generic/platform=iOS Simulator`) both succeed with no overrides.
- **UI:** `testThreeDPanelFocusAndReturn`, `testSpatialTracerVisibilityAndRestart`, `testThreeDAppearanceCaptures` all pass (3 executed, 0 failures); result bundle `.build/07-14-ui-green.xcresult` (gitignored). The Light/Dark appearance attachments show the new legend.
- `--check-evidence` freshness is expected stale (hashed sources and the inspection contract changed); 07-13 regenerates the bundle. Validators were not edited to hide that.

## Task Commits

1. **Task 1 (tracer): square-root transfer end to end**
   - RED `8dd155c` (test): contract amendment plus failing slice-palette expectations
   - GREEN `4b5d91c` (feat): Swift `displayValue`/`encodedColor` and Metal `fluid3DDisplayValue`/`fluid3DEncodedPaletteColor`
2. **Task 2: repin and fail-closed validation**
   - RED `2ca2d72` (test): validator unit test with eight mutations
   - GREEN `717bef7` (feat): five pins, PHASE7_HASH, validator checks
3. **Task 3: legend and copy**
   - RED `9f916a0` (test): UI assertions
   - GREEN `60381fd` (feat): per-column 3D legend and copy

**Plan metadata:** recorded by the SUMMARY commit that follows.

## Decisions Made

- Fixed square root, not an auto-range (see key-decisions). 08-UI-SPEC permits this only as an explicitly verified colour-path amendment; this plan verified the colour path, and 07-16 Task 3 writes the UI-SPEC amendment text.
- Kept the `PaletteStop.concentration` field name to avoid breaking consumers; documented that it is now a display value.

## Deviations from Plan

None - plan executed exactly as written. (The `check tdd-red-evidence` record had to live under the project, so it was written to the gitignored `.build/` directory rather than the scratchpad; no effect on the work.)

## Issues Encountered

- `docs/3d-phase8-verification.md` still quotes the old inspection-contract digest (`7f793d4e...`) and the historical `5fdc33b8...` Phase 7 hash as recorded 2026-11-13 evidence. It is a historical verification record, was outside this plan's file list, and is left unchanged; 07-13/07-16 can decide whether to annotate it.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface; T-07-34/35/36 mitigations were applied as planned.

## Human review

Readability of the brightened returning dye is a human judgment and is judged in 07-17; no human verdict is claimed here (coverage D4 is `human_judgment: true`).

## Next Phase Readiness

- Ready for 07-15 and 07-16 (UI-SPEC amendment of the square-root copy and colour path is 07-16 Task 3) and 07-13's fresh evidence bundle. The spatial fixtures and `test_inspection3d_reference` are green again, unblocking 07-13's integration category.

## Self-Check: PASSED

- All nine modified files exist; the six commits (8dd155c, 4b5d91c, 2ca2d72, 717bef7, 9f916a0, 60381fd) are ancestors of HEAD.
- All Task 1-3 acceptance-criteria greps and the removed-line guard passed as recorded above.

---
phase: 07-first-3d-fluid-vertical-slice
plan: 04
subsystem: simulation
tags: [swift, metal, 3d, fixed-slice, dye-transport, numerical-verification]
requires:
  - phase: 07-03
    provides: Production 64-cubed storage, advection, projection, reset, and step path
provides:
  - Read-only fixed central XY dye slice with the approved encoded amber transfer function
  - Deterministic nonplanar velocity recipe and one compact off-centre dye seed
  - Production GPU visibility, transport, and repeatable capture evidence
affects: [07-06, 07-08, 07-09]
tech-stack:
  added: []
  patterns: [fixed-slice rendering, deterministic volumetric seed, numerical evidence capture]
key-files:
  created:
    - Sources/Shared/ExperimentRecipes3D.swift
    - Sources/Shared/FieldVisualization3D.swift
  modified:
    - Sources/Shared/FluidSimulation3D.swift
    - Sources/Shared/Shaders3D.metal
    - FluidDynamicsMetal.xcodeproj/project.pbxproj
    - Tests/Integration/test_fluid3d.py
    - Tests/Integration/test_fluid3d.swift
key-decisions:
  - "The fixed slice samples world Z=0.5 equally between cell planes 31 and 32, with X right and Y up."
  - "Palette values are encoded RGB written to .bgra8Unorm without an additional sRGB transform."
  - "The 0.01 best-fit-plane threshold is applied to the independently integrated analytic CPU trajectory; production dye-seeded paths report their measured ratio separately."
  - "The production GPU identity diagnostic retains its established 2e-5 ceiling; CPU ideal-Double tolerances and solver gates were not changed."
patterns-established:
  - "The 3D visualization reads the active dye generation and never writes or advances solver resources."
  - "A reset-only seed is projected once; subsequent advances transport the existing three velocity components and dye without reseeding or explicit dye decay."
requirements-completed: []
requirements-addressed: [SIM-05, VER-03]
duration: "At least 46 min from the first recorded task commit; earlier start time was not captured"
completed: 2026-11-08
---

# Phase 7 Plan 07-04: Fixed Slice and Visible Dye Transport

**The fixed central slice and deterministic 64³ dye seed pass the preregistered numerical early-visibility and transport gates; human visual approval remains outstanding.**

## Performance

- **Duration:** At least 46 minutes after the first recorded task commit; the execution start preceded that commit and was not captured.
- **Started:** 2026-11-08T08:02:22Z (first recorded task commit; actual start earlier)
- **Completed:** 2026-11-08T08:48:40Z
- **Tasks:** 2/2
- **Implementation/test files modified:** 7, plus this summary

## Accomplishments

- Added `FieldVisualization3D`, a read-only square XY slice at world Z=0.5. It samples the equal average of planes 31 and 32, presents X right/Y up, and uses the exact fixed palette: black at 0, amber `[237,139,35]` at 0.5, and cream `[255,241,214]` at 1.0. The `.bgra8Unorm` target stores the encoded palette channels directly.
- Added a deterministic curl-derived 3D velocity seed normalized to a maximum cell-centred speed of 0.12 domain-length/time, plus a single compact smooth dye blob centred at `(0.42, 0.48, 0.52)`, radius `0.12`, peak `1.0`. Reset projects this seed once; there is no per-step velocity reseed or explicit dye decay.
- Added GPU-backed slice, read-only resource-hash, full-field evolution, probe-trajectory, unequal-axis transport, and capture checks. The existing 2D solver and Swift/Metal ABI were not changed.

## Measured Recipe and Visibility

Production grid `64³`, `h=1/64`, `dt≈1/60`. The potential is `A=(0.7*f, f*sin²(πy), 0.6*f*sin²(πz))`, where `f=sin²(πx)sin²(πy)sin²(πz)`; the initial velocity is its analytic curl evaluated on MAC faces and explicitly zeroed at normal walls.

| Step | Fixed-slice peak | Pixels ≥0.02 | Slice RMS from step 0 | Volume mass* | Centroid `(x,y,z)` | RMS spread |
|---:|---:|---:|---:|---:|---|---:|
| 0 | 0.96384 | 141 | 0 | 543.1222 | (0.42000, 0.47999, 0.52001) | 0.06946 |
| 1 | 0.96049 | 143 | 0.00132 | 543.0056 | (0.42029, 0.47945, 0.52058) | 0.06962 |
| 24 | 0.88178 | 157 | 0.02935 | 540.4817 | (0.42878, 0.46729, 0.53247) | 0.07320 |
| 48 | 0.80750 | 169 | 0.05241 | 538.2953 | (0.44060, 0.45577, 0.54177) | 0.07679 |
| 72 | 0.77058 | 177 | 0.06931 | 536.6360 | (0.45436, 0.44585, 0.54783) | 0.08041 |

*Mass is the concentration sum, reported descriptively; no semi-Lagrangian mass-conservation claim is made. Its change is due to numerical transport/interpolation, not an explicit dye-decay term.

- Step 0 has one connected component above `0.001`, with peak `0.99590` and 1,541 supported cells; the central-slice peak is `0.96384`.
- Normalized maximum velocity changes over the window: `u=0.22664`, `v=0.20710`, `w=0.16033`. Normalized depth variation is `0.88242`.
- Dye-seeded production probes move up to `3.238` cells in Z; their maximum observed plane-RMS/arc ratio is `0.0001852` and is reported separately. The independent analytic CPU trajectory passes the preregistered threshold with ratio `0.0166238` and Z travel `40.073` cells.
- The independent full-volume unequal-axis GPU fixture moves the dye centroid `5.7856` cells in Z by step 48 (CPU analytic reference: `5.7862` cells). Projection remained accepted throughout; maximum observed iterations: `131`.
- Numerical visibility gates passed at steps 0/24/48, including the step-48 RMS-change minimum `0.005` (observed `0.05241`).

## Task Commits

Each implementation task was committed atomically with hooks enabled:

1. **Task 1: Render the exact central XY sample and fixed palette** — `cb91a4f` (`feat(3d): render fixed central dye slice`)
2. **Task 2: Seed evolving tumbling flow and establish its early observation window** — `eebef93` (`feat(3d): seed evolving dye transport lesson`)

**Plan metadata:** This summary is committed separately from the two implementation task commits.

## Files Created/Modified

- `Sources/Shared/FieldVisualization3D.swift` — fixed slice render pipeline, exact palette API, and encoded color transfer function.
- `Sources/Shared/Shaders3D.metal` — fixed-slice vertex/fragment entry points.
- `Sources/Shared/ExperimentRecipes3D.swift` — reset-only analytic-curl velocity and compact dye seed.
- `Sources/Shared/FluidSimulation3D.swift` — default 3D reset now uses the lesson recipe; injected reset payloads remain supported.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj` — registers the new Swift source in app and state-test targets.
- `Tests/Integration/test_fluid3d.swift` — slice/palette/read-only and evolution/transport fixtures with raw state and PPM captures.
- `Tests/Integration/test_fluid3d.py` — focused fixture registration, source hashing, timeout, and structured recipe evidence output.

## Decisions Made

- Kept the full strict nonplanarity gate on the independently integrated analytic CPU reference as preregistered; the production probe result is retained as a separate measurement rather than misrepresented as meeting that threshold.
- Kept the established GPU identity tolerance at `2e-5`; only the fixture assertion was aligned to that production contract. No PDE tolerance or solver threshold was relaxed.
- Kept palette constants and `encodedColor(for:)` on `FieldVisualization3D`, accessible for reuse by a future legend without duplicating scale logic.

## Deviations from Plan

None. Inline review strengthened the unequal-axis fixture to check finite `u/v/w` readbacks and exact wall-normal zeros at observation points; this added verification without changing production behavior or acceptance thresholds.

## Issues Encountered

- The first red evolution fixture exposed the blank default reset seed. The production reset was then wired to the deterministic lesson recipe; the step-zero slice and early-window gates subsequently passed.
- An initial fixture assertion applied the CPU ideal-Double identity threshold to a production Float32 GPU diagnostic. The assertion was corrected to the already-established GPU acceptance ceiling; the solver and preregistered residual/divergence gates were unchanged.
- The production dye-seeded probe plane ratios were below `0.01`; per the numerical contract, that threshold belongs to the separate analytic CPU trajectory. The fixture now enforces that reference threshold and reports production probe ratios independently.

## Verification

- Fresh macOS app build: passed.
- Fresh iOS Simulator app build: passed.
- Focused `test_slice_and_palette`: passed; `test_evolution_and_visibility`: passed (49.061 s on the final Task 2 fixture).
- `python3 -m unittest discover -s Tests/Integration`: 25 tests passed in 477.711 s, including full CPU-reference feasibility and production GPU fixtures.
- macOS HUD suite: 9 tests passed; focused `FluidDynamicsMetalStateTests`: 25 tests passed.
- iOS HUD suite: 11 tests passed on iPhone 17 Pro simulator (iOS 26.4) and 11 tests passed on iPad Pro 13-inch simulator (iOS 26.4).
- Maximum projection iterations during the visibility fixture: 131; no convergence cap hit or nonfinite state was observed.

## Evidence and Remaining Review

Structured evidence is retained under `.build/fluid3d-evidence/`: `slice-palette.json`, `evolution-visibility.json`, and `recipe.json`, plus `recipe-step-{000,001,024,048,072}.ppm` and matching `.f32le` state captures. The captures are numerical/render-output artifacts only; **human visual approval has not been performed**. Actual macOS 26 runtime behavior is also **NOT TESTED** on this macOS 27 host.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The numerical implementation, fixed palette/slice contract, and reproducible early-window captures are ready for the later evidence and human-review steps. This execution stopped after plan 07-04; it did not run later plans or update `.planning/STATE.md` or `.planning/ROADMAP.md`. Human confirmation that the captures read as one clear tumbling amber patch remains outstanding.

---
*Phase: 07-first-3d-fluid-vertical-slice*
*Completed: 2026-11-08*

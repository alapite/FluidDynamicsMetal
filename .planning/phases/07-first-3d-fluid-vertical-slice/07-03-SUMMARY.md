---
phase: 07-first-3d-fluid-vertical-slice
plan: 03
subsystem: simulation
tags: [swift, metal, mac-grid, pcg, compensated-pressure, numerical-verification]
requires: [07-02]
provides:
  - Compatible closed-box GPU MAC operators and bounded zero-mean diagonal PCG
  - Compensated high/low Float32 pressure with independent full-volume acceptance
  - Drawable-independent reset/step, per-submission status and GPU session failure latch
  - Production numerical, failure, three-in-flight and 600-step finite-state evidence
affects: [07-04, 07-06, 07-08]
tech-stack:
  added: []
  patterns: [scalar-only-status-writes, paired-pressure, staged-reductions, failure-transaction-restore]
key-files:
  created:
    - Sources/Shared/PressureProjection3D.swift
    - Tests/Integration/fluid3d_float32_pcg_diagnostic.swift
    - Tests/Integration/fluid3d_pressure_precision_diagnostic.py
  modified:
    - Sources/Shared/FluidSimulation3D.swift
    - Sources/Shared/SimulationTypes3D.swift
    - Sources/Shared/Shaders3D.metal
    - FluidDynamicsMetal.xcodeproj/project.pbxproj
    - Tests/Integration/fluid3d_reference.swift
    - Tests/Integration/test_fluid3d.swift
    - Tests/Integration/test_fluid3d.py
    - docs/3d-numerical-contract.md
key-decisions:
  - User approved compensated high/low Float32 pressure without changing cap, residual/divergence thresholds or fixture amplitudes.
  - User approved strict Double ideal identity plus a separately derived facewise Float32 storage/Double-evaluator rounding bound.
  - Status failure writes occur only in ordered single-thread passes; volume kernels consume const status.
  - Each queued submission owns its status; GPU failure latches freeze later queued velocity/dye until reset.
requirements-completed: []
requirements-addressed: [SIM-05, VER-03]
duration: 52min
completed: 2026-11-07
post_merge_gate: pending
---

# Phase 7 Plan 07-03: Compatible Projection and Complete Evolution

**Actual production Metal now projects a genuine 3D MAC velocity field with bounded compensated-pressure PCG, explicit failure reporting, and verified offscreen reset/step through a 600-step finite-state soak.**

## Execution and Recovery

- Resumed execution window: approximately **17:43–18:35 UTC, 2026-11-07**, excluding the earlier paused implementation and later post-merge gate.
- **Tasks:** 3/3 plan tasks implemented and focused/integration acceptance passed.
- Recovered the existing `worktree-agent-07-03` worktree at `/Users/abiola/.local/share/opencode/worktree/b6c605/07-03`. The primary checkout's state had missed its pause-only commit and substantial uncommitted work. User explicitly selected **Resume existing**.
- Task 1 already passed in that worktree; Task 2 was blocked at the 320 cap; Task 3 had not started. No inherited implementation was discarded.
- No 3D image, selector, camera, recipe calibration or user-facing renderer path is exposed here. Plan 07-04 owns the lesson seed/fixed-slice validation.

## Accomplishments and Interfaces

- Compatible D/G/A includes every cell, wall-adjacent slab, edge and corner. Constant pressure is null; alternating pressure is not. Reductions have explicit partial/final encoder boundaries and reject nonfinite values.
- `PressureProjection3D.encodeProjection` uses zero-guess, zero-mean diagonal-PCG, **cap 320**, projected preconditioned/search vectors, recomputed true residual, reliable restart, and explicit zero-RHS/breakdown/nonfinite/cap statuses. There are no per-iteration CPU waits/readbacks.
- Pressure storage uses `pressure.ping` as **qHigh** and `pressure.pong` as **qLow**, not alternate pressure generations. Both are initialized and normalized consistently. Operator, gradient and independent Double reconstruction consume both parts.
- Scalar state is **19 float4 lanes / 304 bytes / 16-byte alignment**. Single-thread validation/preparation passes alone write failure state; volume kernels consume const status. The original 48-byte 3D uniform ABI and all established 2D source/ABI remain unchanged.
- Every reset/step returns its own `PressureProjection3D.StatusSlot`; inspect only after its command completes. No three-in-flight submission can overwrite another's diagnostics. Trace capture also checks encoded iteration identity so padding preserves the final genuine convergence record.
- `FluidSimulation3D.encodeReset(command:initialState:)` accepts an optional complete deterministic `Fluid3DInitialState`; omitted input is zero. It initializes both generations, all transported/projection scratch, reduction workspace and session latch, then projects the seed without counting a step. Lesson recipe selection follows in 07-04.
- `encodeStep(command:)` self-advects all components from one old generation into separate transported scratch, enforces walls, projects, restores committed velocity if the solve fails, then advects dye using the new projected flow. A GPU-side session latch causes later already-queued submissions to preserve committed velocity/dye and report prior-session failure. Reset recovers the session.
- Diagnostic inventory exposes complete texture and reduction readback for the harness, not UI mutation. Full status lanes, reduction workspace, pressure parts, all scratch and both velocity/dye generations are finite-scanned at reset and steps 1/72/600.

## Numerical Results — Production GPU and Independent Readback

Host: **Apple M3 Pro, macOS 27.0 (26A428), Xcode/Metal Toolchain 27.2**. Both projection and evolution tests load the freshly built Mac app's actual `default.metallib` with Metal validation. An mtime guard rejects a metallib older than `Shaders3D.metal`.

Each row independently reconstructs q in Double, computes `b-Aq` and divergence from returned velocities across the full volume, enforces both original **1e-5** timestep-scaled infinity gates, and checks the conditional **1000x** reduction. Maximum wall-normal value is exactly zero throughout.

| 64³ family | GPU iterations | Independent residual DT | Independent divergence DT | Cap hit |
|---|---:|---:|---:|---|
| Zero RHS | 0 | 0 | 0 | No |
| Constant pressure | 0 | 0 | 0 | No |
| Alternating pressure | 2 | 2.919195e-6 | 2.919195e-6 | No |
| Manufactured cosine | 180 | 1.174621e-6 | 1.174621e-6 | No |
| Mixed-frequency asymmetric | 234 | 9.552601e-7 | 9.541711e-7 | No |
| Wall/edge/corner | 317 | 2.571470e-6 | 2.225240e-6 | No |
| Divergence-free | 0 | 5.086263e-7 | 5.086263e-7 | No |

Projection compared **11,096,064** values; maximum elementwise absolute error versus independent Double reference was **1.232651e-5**, within `2e-5 + 2e-4*abs(reference)`. All scalar/field values were finite. The wall stress case has only a **3-iteration cap margin**; this is recorded risk, not permission to increase the cap or claim real-time performance.

Ideal-Double identity errors stayed at or below **9.095e-14**. Stored-output identity is separately bounded facewise under the approved amendment: mixed case error **1.358786e-8** (maximum derived bound **1.798150e-8**); wall stress error **1.330060e-6** (maximum derived bound **1.557783e-6**). Actual acceptance checks each cell against its own six-face budget, not merely these global maxima.

Negative tests reject zero, negative and NaN denominators, incompatible mean, NaN input and intentionally exhausted cap. Three queued status slots retain one zero-RHS success and two distinct cap failures. Evolution tests also queue three submissions with an injected first-step failure and prove exact committed velocity/dye preservation, followed by reset recovery.

## Reset/Step and Soak

- Independent CPU Double reset and one-step payload uses Float32-rounded unequal three-component analytic inputs, independently formed projection and RK2/trilinear advection. Its manifest/payload hashes and sizes are checked before GPU testing.
- Zero velocity remains zero; uniform dye **0.375** is preserved within **2e-6**, with no explicit decay.
- Full reset/one-step reference comparisons pass; both generations match after reset.
- **600 production advances passed**; final strengthened soak took **142.960 seconds** (soak portion only), maximum solve count **144 iterations**. Reset and steps 1/72/600 scanned every evolution/scratch texture generation, all reduction values and full status allocations.
- Step 600 GPU diagnostics: divergence DT **9.536743e-7**, true residual DT **9.545514e-7**; no failed solve or cap hit.
- This is numerical stress coverage, **not** Phase 9 lesson completion/replay or Phase 10 performance acceptance.

## Verification

- Fresh no-override Mac Debug build — **PASS**.
- Fresh no-override iOS Simulator Debug build — **PASS**; existing platform/`UIRequiresFullScreen` warnings are not runtime or physical-device proof.
- `python3 -m unittest discover -s Tests/Integration` — **PASS, 23 tests, 352.071 s**, including all production 3D fixtures, read-only-volume-status regression, CPU oracle and established 2D/renderer/educational regressions.
- Separate settings/CPU-reference check — **PASS, 5 tests, 18.050 s**; quick reference 0.021 s, full64 CPU feasibility 1.953 s.
- `git diff --check` — **PASS**.
- Post-merge Mac state/HUD build/test gate: **pending at summary creation**; orchestrator must record its actual result before updating wave completion.

Evidence files are generated, intentionally ignored `.build/fluid3d-evidence/{operators,projection,reset-finite,storage-abi,advection-boundaries}.json`. They record commands, toolchain, source hashes, independent fixture hashes and production library hash.

- Original immutable contract-prefix SHA-256: `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`.
- Complete amended contract SHA-256: `5fdc33b839d7f135a828ac9e6e3c3b4e7adba03d5341771ddbed4b13767951a8`.
- Tested worktree metallib SHA-256: `19382fb355a0fb8ac66c240ff78ccb050d9ece6be26ab0545be9572a42fdff1d`.

## Task Commits

1. **Recovered Tasks 1/2 regression fixtures and Task 3 RED coverage:** `3eddb6f` — production/reference/negative/independent-readback/evolution tests and diagnostic probes.
2. **Approved numerical contracts:** `8a54ea7` — compensated pressure and derived storage/evaluator rounding amendments.
3. **Tasks 1/2 and GPU support for Task 3:** `7c0c5a9` — compatible operators, compensated PCG, scalar-only status mutation, guarded evolution passes and source membership.
4. **Task 3 assembly:** `d89b1b6` — complete reset/step, scratch inventory and transactional failure recovery.

The inherited Task 1/2 source changes were entangled and uncommitted at recovery; they were preserved and committed together, rather than fabricating separate original task commits. Missing APIs, independent residual, const-status regression, trace preservation and negative-injection tests were observed failing before their respective fixes. Some inherited GPU support was already present when new reset/step API RED coverage was added; this is not claimed as a pristine three-task TDD history.

## Deviations and Issues

1. **User-approved architecture revision:** Single-Float32 pressure hit the cap; even once-rounded analytic cosine pressure had residual DT **1.872381e-5**. Added compensated high/low pressure after explicit approval, without changing cap, primary numerical gates or fixture amplitudes.
2. **User-approved precision-contract revision:** Strict stored-output Double identity failed at **1.358786e-8** for mixed-frequency data. Kept strict ideal-Double algebra and independently derived/verified facewise storage/evaluator rounding; did not fit a looser constant to observed output.
3. **Fixture correction:** The previously unreachable three-in-flight fixture incorrectly expected a nonzero affine field to converge in one iteration. Its successful control is now explicit zero RHS; two distinct cap-failure submissions remain.
4. **Review fixes:** A separate read-only general reviewer found missing independent divergence acceptance, failure-path state races, incomplete finite scans and padded trace overwrite. Tests reproduced the gaps; second static review reports no unresolved findings. See `07-03-REVIEW.md`. This is independent static review, not typed-GSD runtime verification.
5. **Timeout:** The first soak hit the outer shell's 120-second timeout and was correctly inconclusive. A rerun with explicit 1800-second allowance passed; the final stronger soak also passed in the full suite.

## Requirement Status and Next Plan

No Phase 7 requirement is marked complete here. `SIM-05` and `VER-03` have numerical prerequisites/evidence, but end-to-end evolving lesson, fixed slice and renderer/native integration remain ahead. Continue with **07-04, Wave 4** only after post-merge acceptance. Preserve explicit human visual/interaction approval at **07-09**. Actual macOS 26 runtime and physical-device multitouch remain **NOT TESTED**.

## Self-Check: PASSED

All three plan tasks have actual production fixture evidence, both app builds and the full 23-test integration regression passed on the recorded sources, key artifacts exist, and implementation/test/contract commits are recorded above. This self-check is plan-scope/pre-merge; it does not substitute for the pending post-merge gate or claim phase completion.

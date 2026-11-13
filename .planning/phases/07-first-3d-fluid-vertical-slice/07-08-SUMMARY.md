---
phase: 07-first-3d-fluid-vertical-slice
plan: 08
subsystem: verification
tags: [swift, metal, numerical-evidence, benchmark, documentation]

# Dependency graph
requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: [production 64-cubed solver, fixed-slice renderer, native Mac 3D controls]
provides:
  - Reproducible solver-only and solver-plus-fixed-slice benchmark evidence
  - Attributed production numerical, regression, and retry results
  - Scoped Mac 3D usage and verification documentation
affects: [07-09, phase-7-verification]

# Tech tracking
added: []
patterns:
  - Keep offscreen GPU completion, host timing, and displayed frame pacing as separate metrics.
  - Link documented outcomes to machine-readable manifests with source, metallib, contract, log, and reference hashes.
  - Preserve initial simulator failures alongside successful focused and full-suite retries.

key-decisions:
  - Phase-owned requirements remain pending until the blocking 07-09 human visual/interaction review is answered.
  - macOS 26 runtime and physical-device multitouch remain NOT TESTED; displayed frame pacing remains NOT MEASURED.
  - The 3D benchmark is an early solver/slice baseline, not Phase 10's 30-fps qualification.

requirements-completed: []

# Metrics
duration: resumed execution; exact elapsed time not reliably captured
completed: 2026-11-08
---

# Phase 7 Plan 08: Verification and Evidence Summary

**The first 3D slice now has attributed production numerical results, an early solver/slice baseline, and current Mac usage/verification documentation; the human review remains pending.**

## Accomplishments

- Recorded the 64³ production numerical fixtures, all-wall projection outcomes, early step 0/24/48/72 observations, and linked PPM/state captures in `docs/3d-phase7-verification.md`.
- Documented the exact Apple M3 Pro/macOS 27.0/Xcode 27.2/Swift 6.4.2 environment and locked benchmark protocol. The separate solver-only and solver-plus-fixed-slice medians were 161.410 ms and 317.521 ms GPU time; displayed frame pacing is explicitly NOT MEASURED.
- Recorded both-target builds, Mac tests, full integration, and iPhone/iPad simulator outcomes. The initial iPhone 9/11 and iPad 8/11 failures, isolated retries, reboot recovery, and final 11/11 suites remain attributed in the regression matrix.
- Updated `README.md` with the Mac grouped 2D/3D selector, paused 3D entry and transport, fixed XY/amber concentration semantics, hidden 2D-only controls, keyboard/focus behavior, safe failure/retry, 2D return, scoped verification commands, and later-phase boundaries.
- Kept Phase 7 requirements pending for the blocking 07-09 user review; actual macOS 26 runtime and physical-device multitouch remain NOT TESTED.

## Verification

Recorded outcomes in `.build/fluid3d-evidence/regression-matrix.json`:

- Mac Debug and iOS Simulator Debug builds: **PASS**, exit 0.
- Mac state + HUD suite: **PASS**, 40/40 (25 state, 15 HUD).
- Full integration suite: **PASS**, 28/28 in 572.001 seconds.
- iPhone 17 Pro/iOS 26.4 HUD: **PASS**, final 11/11 after initial 9/11 and successful focused retries.
- iPad Pro 13-inch M5/iOS 26.4 HUD: **PASS**, final 11/11 after initial orientation failures, reproduction before reboot, and successful post-reboot retry.
- `test_evidence_schema`: **PASS**, 1/1.
- Full production 3D CPU/GPU fixtures and benchmark: **PASS**; the 320-iteration cap, projection tolerances, and preregistered thresholds were not relaxed.
- Final `--check-evidence --quick` and full `--check-evidence`: **PASS** after the report/README edits; visual review remains PENDING. The final output is confirmed in the execution record for this plan.

Detailed results, commands, hashes, distributions, resource inventory, and exact retry history are in `docs/3d-phase7-verification.md` and `.build/fluid3d-evidence/`.

## Scope and status

- **Human visual/accessibility/native-interaction review:** PENDING for 07-09; automated UI evidence does not approve it.
- **Actual macOS 26 runtime:** NOT TESTED on the macOS 27 host.
- **Physical-device multitouch:** NOT TESTED.
- **Displayed frame pacing:** NOT MEASURED; offscreen timing is not FPS.
- **Phase requirements:** remain pending until the explicit user checkpoint response.
- **Commits:** none; existing work remains uncommitted.

## Next

Prepare and launch the fresh root Mac Debug app for plan 07-09, attach app identity/hash and launch evidence to the report, present the review checklist, and stop for the user's explicit approval or issue report. Do not create the 07-09 summary or mark requirements complete before that response.

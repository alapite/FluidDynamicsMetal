---
phase: 08-spatial-inspection
plan: "08"
subsystem: testing
tags: [python, swift, metal, evidence, regression, documentation, tdd]
requires:
  - phase: 08-spatial-inspection
    provides: Spatial presentation, native controls, tracers and complete-state fixtures from 08-01 through 08-07
provides:
  - Separately versioned fail-closed inspection evidence schema and actual-bundle CLI
  - Fresh two-target, full Mac, full integration and iPhone/iPad HUD matrix with retained failures/retries
  - Accurate spatial-inspection usage and unchecked mandatory human-review handoff
  - Launchable Mac app with metallib identity matching production GPU evidence
affects: [08-09, 09-repeatable-3d-advection-lesson, 10-volume-view-and-measured-release-quality]
tech-stack:
  added: []
  patterns:
    - Separate synthetic schema validity from actual artifact acceptance
    - Bind named state inventories and complete schedules to source/tool/metallib/oracle identities
    - Append-only measured regression attempts with real logs and result bundles
key-files:
  created:
    - docs/3d-phase8-verification.md
    - .planning/phases/08-spatial-inspection/08-08-REVIEW.md
    - .planning/phases/08-spatial-inspection/08-08-SUMMARY.md
  modified:
    - Tests/Integration/test_fluid3d.py
    - README.md
    - .planning/phases/08-spatial-inspection/08-VALIDATION.md
key-decisions:
  - "Actual Phase 8 evidence requires all six regression categories; missing mobile evidence is an error, never a skip."
  - "Keep legacy fixed-slice benchmark schema/workload semantics and the historical Phase 7 report unchanged."
  - "Retain failed Mac/iPhone attempts separately from passing unchanged-source retries; no assertions weakened."
  - "All Phase 8 requirements stay pending actual mandatory 08-09 human review."
patterns-established:
  - "Synthetic inspection manifests exist only in memory and cannot validate as actual acceptance evidence."
  - "Each fixture execution records measured duration/exit/log identity; previous logs are timestamp-retained."
requirements-completed: []
duration: approximately 63 min
completed: 2026-11-15
---

# Phase 8 Plan 08: Fresh Inspection Qualification Summary

**A fail-closed spatial-evidence validator now binds complete GPU/state coverage to a fresh passing build/Mac/integration/iPhone/iPad matrix, with accurate usage and an unapproved human-review handoff.**

## Performance and scope

- **Duration:** Approximately 63 minutes including investigation, full retries,
  matrix execution, documentation and inline review.
- **Started:** Approximately 2026-11-15T07:20Z; exact initial assistant timestamp
  was not captured. The first task commit is at 07:22:34Z.
- **Completed:** 2026-11-15, approximately 08:23Z.
- **Actual matrix start:** 2026-11-15T07:29:07.787536Z.
- **Matrix command wall time:** 2,950.717 s (49.18 min), including all attempts,
  discovery and app preparation; excludes investigation gaps and other work.
- **Tasks:** 2/2.
- **Task/review files:** 5; summary and STATE/ROADMAP tracking are additional.
- Sequential current-checkout execution, no worktree/branch changes, no model
  override or additional agent dispatch. This is a general-agent workaround,
  not typed gsd-executor execution.

## Accomplishments

### Task 1 — Separate fail-closed inspection contract

- Added `Fluid3DTests.test_inspection_evidence_schema`, schema 1
  `kind: fluid3d-inspection`, explicit synthetic/actual evidence class and CLI:
  `python3 Tests/Integration/test_fluid3d.py --verify-inspection-evidence .build/inspection3d-evidence`.
- Requires exact configuration/seed, source/metallib/full numerical contract/
  inspection contract/oracle/reference hashes, host/tool/build identity,
  commands, measured durations, passing exits, real logs and XCTest bundles.
- Collects all five spatial/routing/tracer/independence reports in the separate
  namespace while retaining established `.build/fluid3d-evidence/` consumers.
  Routing keeps its original numerical-reference identity; the top-level bundle
  separately includes the full inspection oracle and contract.
- Pins independent named resource layouts and finite per-resource errors:
  reset/latest/submitted slots, optional full trace, all texture generations,
  workspace/latches and tracer positions. Requires 160 detector negatives,
  29 exact paused cases, four visibility/drawable schedules at 0/1/24/48,
  redraw/backing-scale/viewport schedules, Restart and failure/recovery outcomes.
- Negative tests delete required categories/fields and corrupt hashes,
  tolerances, workload, resource inventory/errors, status bytes, metadata,
  schedules and failures. Synthetic fixtures remain in memory and are rejected
  for actual acceptance. No synthetic GPU manifest was published.
- Requires macBuild/iosBuild/macTests/integrationTests/iphoneHUD/ipadHUD PASS.
  Explicit manual/runtime/device-only/pacing fields cannot be inferred from
  automated success. Legacy benchmark validator/workload labels are unchanged.

### Task 2 — Fresh matrix, real app and scoped documentation

- Executed both exact no-override builds, full Mac and integration suites,
  discovered-device full iPhone/iPad HUD suites and `./build-macos.sh`.
- Preserved every failed/retry log and result bundle with distinct names.
  Actual commands, identities, statuses, counts, durations and all attempts are
  in `.build/inspection3d-evidence/regression-matrix.json`.
- README documents native plane/shared depth, orbit/zoom, keyboard increments,
  reset scopes, passive hidden advancement, opaque-black-sheet occlusion and
  exclusive canvas/panel gestures, preserving 2D/mobile usage.
- `docs/3d-phase8-verification.md` indexes actual numerical/state/UI results,
  reference environment, hashes, tolerances, inventories, captures and all
  attempts. Human checklist items remain unchecked.
- Validation infrastructure is genuinely produced/tested
  (`wave_0_complete: true`), not a human or phase acceptance claim.

## Task commits and TDD evidence

| Task / gate | Commit | Actual evidence |
|---|---|---|
| Task 1 RED | `669d887` | `.build/08-08-task1-red-assertion.log`: fails because separate Phase 8 validator is absent; legacy test passes |
| Task 1 GREEN | `bc4a52b` | `.build/08-08-task1-green.log`: new/legacy schema 2/2, 4.113 s |
| Task 1 freshness refinement | `c44365a` | `.build/08-08-task1-freshness.log`: new/legacy schema 2/2; binds matrix and independent payload identities |
| Task 2 qualification/docs | `66cf0e6` | Full passing final matrix, real-evidence CLI and documentation/review artifacts |

The first draft RED run produced a missing-helper NameError; it is retained
separately in `.build/08-08-task1-red.log`. Before implementation/RED commit,
the test was corrected to an explicit failing behavioral assertion that the
separate validator is missing. Both initial logs remain available.
No refactor commit was necessary.

## Final fresh verification

All matrix commands ran after the final code edit (`c44365a`); only docs and
evidence metadata changed afterward. This is the final build/test gate, not
borrowed historical evidence.

| Gate | Actual final outcome | Command wall duration / evidence |
|---|---|---|
| Exact Mac Debug arm64 build | PASS, exit 0 | 4.809 s; `logs/macBuild-attempt-1.log` |
| Exact generic iOS Simulator Debug build | PASS, exit 0 | 2.388 s; `logs/iosBuild-attempt-1.log` |
| Full Mac state + HUD | **47/47**, no skips | 402.944 s; `logs/macTests-attempt-2.log`, `macTests-attempt-2.xcresult` |
| Full integration | **45/45** | 1,044.695 s command / 1,044.623 s unittest; `logs/integrationTests-attempt-1.log` |
| iPhone 17 Pro / iOS 26.4 | **11/11**, no skips | 287.356 s; `logs/iphoneHUD-attempt-2.log`, `iphoneHUD-attempt-2.xcresult` |
| iPad Pro 13-inch (M5) / iOS 26.4 | **11/11**, no skips | 252.661 s; `logs/ipadHUD-attempt-1.log`, `ipadHUD-attempt-1.xcresult` |
| Launchable Mac build | PASS, exit 0 | 8.099 s; `logs/launchableApp-attempt-1.log` |
| Focused schema/state gate | **2/2** | 7.305 s including compilation; `.build/08-08-focused-final.log` |
| Actual inspection-evidence CLI | PASS, exit 0 | `.build/08-08-evidence-final.log` |
| All 14 GPU report source/metallib/reference audit | PASS | `.build/08-08-final-artifact-audit.log` |
| Diff whitespace | PASS | `git diff --check` |

Table paths beginning `logs/` or ending `.xcresult` are relative to
`.build/inspection3d-evidence/`. Each XCTest result has an extracted
`.summary.json`; actual terminal summaries were read.

### Failures/retries — retained, not relabelled

- **Mac attempt 1: FAIL, 45/47, exit 65, 672.312 s.** Workflow/keyboard test
  lost transport controls from the accessibility hierarchy; mouse/resize test
  timed out amid unrelated desktop-window interruption reports. The complete
  unchanged-source full retry passed 47/47. Initial:
  `logs/macTests-attempt-1.log`, `macTests-attempt-1.xcresult`.
- **iPhone attempt 1: FAIL, 9/11, exit 65, 275.002 s.** Landscape fade remained
  at 17%, and the large-text selector lacked the requested lesson item.
  Similarity to Phase 7 orientation/layout failures is not proof of cause.
  Rebooted only the selected simulator, awaited boot completion, and reran the
  full suite unchanged: 11/11. Initial:
  `logs/iphoneHUD-attempt-1.log`, `iphoneHUD-attempt-1.xcresult`.
- Device IDs discovered in this run:
  iPhone `8393A81F-69D4-439E-AF8E-ED7665022800`;
  iPad `98C63B09-8AB0-4B26-B9C4-5277D60FCBD5`, both 26.4 / 23E244.
- No app source, test assertion, tolerance or coverage was weakened.
  iOS UIScene/UIRequiresFullScreen/AppIntents advisories remain in real logs.

## Actual numerical/resource results and identities

- **Host:** Mac15,6 / Apple M3 Pro, arm64; macOS 27.0 (26A428),
  Xcode 27.2 (27B52), Swift 6.4.2, Metal 32023.922 (27.2 toolchain), Debug.
- **Metallib:** `0481040a6a18d577b2a03385b0bf32de65f71b5f21e2810cc5051e3c36e3aaef`.
- **Full numerical contract:** `5fdc33b839d7f135a828ac9e6e3c3b4e7adba03d5341771ddbed4b13767951a8`.
- **Inspection contract:** `7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7`.
- **Independent oracle:** `6fb1e9a948af7fd0bd49131abf8a2292fc12306759f59bd4b9eaf189bb3cf5fc`.
- **Inspection reference manifest:** `2411af51ecf9979c631ef3d284f423854c3de68b38e64adec21b91b5be3d8d50`.
- Complete 34-file spatial and separate 24-file legacy source inventories are
  recorded in the actual JSON manifests.
- Spatial samples 24/24; guide area scale ratio 3.9727965.
- Tracer forward-RK2 maximum oracle error **2.574921e-8** across 4,096 comparisons;
  all 55 boundary/affine probes and 48 production steps passed.
- Complete reset inventory **37 resources / 33,776,184 bytes**; 160 negatives,
  29 exact paused cases; maximum equal-step resource error **0**.
  Drawable reads 195/196/195/0 for shown/hidden/alternating/nil.
- All seven projection families passed, maximum 317/320 iterations. Maximum
  post-projection timestep-scaled divergence 2.919195e-6; exact wall zeros.
  The 600-step finite soak passed in 142.395 s, maximum 144 iterations.
- Existing 2D renderer/educational and bundle/build checks passed in full
  integration. The established 2D solver/Swift-Metal ABI is unchanged.

## Files, app and human-review handoff

- `Tests/Integration/test_fluid3d.py` — schema, negative tests, CLI, spatial
  report collection, measured execution/log identity and previous-log retention.
- `README.md` — supported current Mac inspection and preserved 2D/mobile usage.
- `docs/3d-phase8-verification.md` — fresh results and unchecked actual review.
- `08-VALIDATION.md` — genuinely performed automated checks, not acceptance.
- `08-08-REVIEW.md` — distinct **inline** review against the original plan.
- Actual manifests: `.build/inspection3d-evidence/{manifest,regression-matrix}.json`.
- Retained command recorder: `.build/08-08-run-matrix.py` (ignored diagnostic
  artifact, no dependency installed).
- Launchable app:
  `/Users/abiola/Documents/Code/Swift/FluidDynamicsMetal/FluidDynamicsMetalOSX.app`.
  Executable SHA-256
  `398ec38146ce001cd0b64824a70c410463cf00c56d9c6aa02551292e2ba1476e`;
  copied metallib matches actual fixture evidence exactly.
- Real offscreen captures: `.build/inspection3d-evidence/cube-*.ppm` and
  `tracer-occlusion-*.ppm`; exact names in fixture reports. Native screenshots
  are in the fresh Mac `.xcresult`. None is human visual/accessibility approval.

## Distinct inline review and deviations

Distinct inline review passed with findings resolved; see `08-08-REVIEW.md`.
It is not independent-agent verification. Review strengthened identity binding
and native/source attribution before the full final matrix.

**Deviations:** No app/solver/scope change. One Task 1 freshness refinement
commit supplements the RED/GREEN pair, and one full Mac plus one full iPhone
retry was needed. Retaining an ignored command recorder made measurements
reproducible without adding a project dependency. These support the planned
evidence/coverage contract; no later plan was executed.

**User setup:** None.

## Next readiness and acceptance limits

08-08 is complete; Phase 8 remains **EXECUTING, 8/9**, next **08-09 / Wave 9**.
INS-01/02/03/04 and CTRL-08 remain **pending**. `requirements-completed: []`
intentionally honors the explicit human-acceptance boundary instead of marking
associated IDs complete. Actual human review is mandatory and not auto-approved.
No 08-09, phase-level verification/completion or auto-advance ran.

Phase 7 historical report and six pending user-facing requirements are unchanged.
VoiceOver/real pointer feel, actual macOS 26 and physical multitouch remain
**NOT TESTED**; displayed pacing remains **NOT MEASURED**. Phase 9 teaching,
speed/full600-step/all-speed repeatability and Phase 10 volume/performance
acceptance remain out of scope.

## Self-Check: PASSED

Both original task acceptance gates, actual RED/GREEN commits, full final matrix,
fresh real-evidence CLI, all 14 GPU report freshness checks, app-metallib match,
required documentation/capture/result paths and distinct inline review exist.
No synthetic acceptance evidence or human/runtime/device/FPS PASS was fabricated.

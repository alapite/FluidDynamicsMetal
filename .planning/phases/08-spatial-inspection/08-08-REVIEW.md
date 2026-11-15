# 08-08 — Distinct Inline Review

Reviewed against `08-08-PLAN.md`, both task acceptance criteria, the unchanged
numerical/inspection contracts and D-17/D-20/D-21. This is **inline review**,
not independent-agent verification. No separate reviewer agent ran.

## Findings and disposition

1. **Matrix identity binding — resolved before the fresh matrix.** The new
   bundle checker must compare only the six mandatory regression categories,
   allowing separately recorded device discovery/app preparation without
   accidentally treating them as missing fixture results. It also binds the
   matrix source/environment/coverage to the actual manifest, and verifies the
   asymmetric oracle payload hash. Commit `c44365a`; focused new/legacy schema
   tests pass. No benchmark schema/workload change.
2. **Native-control source attribution — resolved before the fresh matrix.**
   The separate spatial source inventory now includes both controllers, project
   membership, native Mac/iOS HUD test sources and the production state harness.
   Legacy nonspatial inventory remains distinct. No app implementation changed.
3. **Historical documentation wording — corrected.** README no longer claims
   the current Mac preview is face-on-only or that camera/tracers are future
   work. The historical Phase 7 report itself is unchanged. Current usage
   describes shared depth, native keyboard camera alternatives, exact reset
   scopes, opaque-black-sheet occlusion and exclusive canvas/panel gestures.

## Original-plan checklist

- Task 1 has observed failing assertions before implementation and passing
  new/legacy schema tests afterward. The initial missing-helper error and the
  corrected expected RED assertion have separate retained logs. RED commit
  `669d887`, GREEN `bc4a52b`, freshness refinement `c44365a`.
- Separate schema 1 `fluid3d-inspection` and CLI do not relabel the Phase 7
  fixed-slice benchmark. Synthetic data is built only in memory, explicitly
  labelled and rejected for actual acceptance.
- Negative schema tests remove every top-level category and required source,
  configuration, environment, coverage, tolerance, fixture, result and matrix
  field; corrupt sources/contracts/oracle/workload; remove detector/inventory/
  schedule/failure categories; corrupt resource names/bytes/errors, exact status
  bytes, counters, drawable schedule and failure outcomes. Native manual statuses
  cannot become PASS through automation.
- Complete-state schema pins actual resource names, dimensions, formats/bytes,
  finite per-resource errors, exact paused bytes/identity and discrete metadata;
  reset/latest/three-submitted and full optional trace inventories are separate.
- Required schedule gates are 29 exact paused cases, four independently
  scheduled visibility/drawable cases at 0/1/24/48, 0/1/2 redraws, 1×/2× scales,
  wide/tall/zero viewport, queued slots and Restart at 0/1. Existing 160 negative
  detector names and embedded initial/active failures are required.
- Actual bundle validation requires current source/metallib/full-contract/
  inspection-contract/oracle/reference identities, real command logs and
  XCTest bundles, six passing matrix categories and measured durations.
- Both target builds, full Mac, full integration and actual discovered
  iPhone/iPad HUD commands are recorded independently; attempts are append-only.
  Final terminal results must be read before a completion claim.
- No solver, 2D Swift/Metal ABI, app controls or numerical thresholds changed.
  No requirements are marked complete. 08-09 remains mandatory; no phase-level
  completion/auto-advance or Phase 9/10 acceptance is authorized.

## Final evidence gate

PASS at final code state: exact Mac/iOS builds, full Mac 47/47, full integration
45/45, discovered iPhone/iPad HUD 11/11 each, launchable app preparation and
actual-evidence CLI exit 0. Initial Mac 45/47 and iPhone 9/11 attempts remain
FAIL in the append-only matrix; full unchanged-source retries passed, with a
targeted iPhone simulator reboot. No flaky-test assertion was weakened.
All `.xcresult` summaries were read and the copied app metallib matches the
fresh fixture hash. See `docs/3d-phase8-verification.md` and
`.build/inspection3d-evidence/{manifest,regression-matrix}.json`.

**Final distinct inline review: no unresolved blocking finding.** The review
is not a substitute for these actual gates or for mandatory 08-09 human review.
All five Phase 8 requirements remain pending. No 08-09 or phase-level
verification/completion ran.

# 08-07 — Distinct Inline Implementation Review

Reviewed 2026-11-14 against both tasks, acceptance criteria and threats in
`08-07-PLAN.md`, the inspection contract and the original `3901109` checkout.
This is **inline review**, not independent-agent verification.

## Findings and resolution

1. **Ownership-audit container gap — fixed.** The first audit traversed known
   owners and optionals but could miss a buffer held in a collection. The new
   behavioral guard failed with “Ownership audit silently omitted a
   collection-held evolution allocation”; traversal now includes collections,
   dictionaries and tuples. RED: `.build/08-07-review-red.log`; GREEN:
   `.build/08-07-review-green.log`. Explicit expected names/shapes/lengths remain
   a second, separate guard; reflection is not the registration list.
2. **Archived metadata gap — fixed.** Comparisons asserted exact counters,
   pending work, roles and input but initially reported resource metrics only.
   Paused, equal-step and pre-drain records now archive the compared metadata;
   the Python production test requires checkpoint counters and paused pending=2.
3. **Inherited spatial allocation expectation — fixed.** The old fixture
   expected two pipelines before tracers were integrated. The actual allocator
   creates sheet, tracer and guide pipelines. Require exactly three distinct
   production labels and reuse across viewports, rather than relaxing the
   assertion to “at least two.” RED: `.build/08-07-final-regressions.log`;
   focused GREEN: `.build/08-07-spatial-repair.log`.
4. **Inherited Mac HUD assumptions — fixed.** The factual note expectation
   lacked the approved tracer/opaque-sheet copy. Its normalized title-bar drag
   landed in content after Phase 8 made the panel taller. Update the expected
   copy and use an 8-point title-bar offset; do not change production UI.
   RED: `.build/08-07-mac-tests.log`; focused GREEN:
   `.build/08-07-ui-repair.log`; full GREEN:
   `.build/08-07-mac-tests-final.log` and
   `.build/08-07-mac-tests-final.xcresult`.

## Original-plan checklist

- **T-08-inventory:** All 32 texture generations, complete reduction workspace,
  both latches, one in-place tracer buffer and every registered retained status
  allocation are staged. There is no tracer ping/pong/scratch allocation to
  invent. Optional trace allocation is included, including its full tail.
  160 staged-byte/omission/rename/resize/finite/metadata/identity negatives pass.
- **Undefined bytes:** An actual trace reuse/initialization regression failed
  with nonfinite tail bytes. Allocation and each traced projection now clear
  the entire trace deterministically. This is a targeted trace reset test, not
  mutation of solver resources to make the comparator appear effective.
  Numerical thresholds, shader ABI and pressure algorithm are unchanged.
- **T-08-queue:** Readback blits use the production queue and complete before
  decode. Reset/latest/three-submitted ownership is captured before callback
  drain; all five status objects are distinct, finite and accepted after the
  staging fence. Pending=2 paused work is preserved until ordinary drain.
- **T-08-routing:** 29 paused cases at evolved step 2 preserve bytes, allocation
  identity, roles and metadata. Plane/depth, camera, recovery, visibility and
  wide/tall/1×/2×/zero viewports have positive value/matrix/image/viewport checks.
  Direct input entry points introduce no fluid contacts.
- **Independent scheduling:** A separately reset `FluidSimulation3D` followed by
  `TracerSystem3D` advances without Renderer or visualization. Four production
  Renderer schedules compare complete resources at 0/1/24/48. Status/latches,
  seeds and discrete metadata are exact; floating fields use finite-first
  absolute 2e-6, with measured maximum error 0. Real drawable reads occur in
  shown/hidden/alternating cases; nil case reads zero drawables.
- **Restart:** Nondefault camera/plane/depth/hidden visibility survives Restart,
  pending work clears, reset state is byte-identical across fresh allocations,
  and step 1 matches the independent schedule. Only process-local identity and
  session-generation token are normalized between fresh sessions.
- **Failures:** Report embeds newly executed initial/restart allocation,
  pipeline, reset, tracer faults, active depth failure/retry, active tracer
  advance, projection failure and stale-completion assertions.
- **Actual key links:** The Swift fixture constructs `Renderer`, calls its
  presentation-only and logical-step paths, and stages `FluidSimulation3D` and
  tracer resources. Filename-based “Target not referenced in source” results
  are false negatives; the Swift symbol dependencies are present and exercised.
- **Regression:** Both no-override app builds pass. Full Mac suite passes
  25 state + 22 UI tests. Final targeted matrix passes 19/19, including 600-step
  finite soak, all seven production projection families, advection, spatial,
  tracer, renderer and six 2D/educational regressions. Evidence source/reference
  freshness audit passes for all 11 targeted GPU reports.

## Outcome and limits

**No unresolved blocking finding for 08-07.** See
`.build/08-07-final-regressions-pass.log` and
`.build/08-07-evidence-audit.log`. Historical benchmark helpers and evidence
meaning are preserved. This is not the 08-08 phase evidence/schema workflow,
phase-level verification, human acceptance, measured FPS or Phase 9 all-speed
repeatability. 08-09 remains mandatory; all Phase 8 requirements remain pending.

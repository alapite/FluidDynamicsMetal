---
phase: 08-spatial-inspection
plan: "01"
subsystem: rendering
tags: [swift, camera, inspection, oracle, tdd]
requires:
  - phase: 07-first-3d-fluid-vertical-slice
    provides: Immutable MAC numerical contract and existing app/state build targets
provides:
  - Preregistered inspection coordinate, camera, tracer and complete-state contract
  - Independent Double slice/MAC/RK2 JSON and binary expectations
  - Validated resource-free inspection values and full-aspect Metal camera math
affects: [08-02, 08-03, 08-05, 08-07, 08-08]
tech-stack:
  added: []
  patterns: [Direct-source pure Swift math tests, Independent scalar camera evaluator, Pinned whole-document inspection contract]
key-files:
  created:
    - docs/3d-inspection-contract.md
    - Tests/Integration/inspection3d_reference.swift
    - Tests/Integration/test_inspection3d_reference.py
    - Sources/Shared/InspectionState3D.swift
    - Sources/Shared/Camera3D.swift
    - Tests/Integration/test_inspection3d_state.swift
    - Tests/Integration/test_inspection3d_state.py
  modified:
    - FluidDynamicsMetal.xcodeproj/project.pbxproj
key-decisions:
  - Explicit default initializers prevent bypassing finite validation through synthesized memberwise construction.
  - Native slider yaw clamps at endpoints; canvas gesture yaw wraps without adding to extreme input before remainder.
  - Requirement completion remains empty because this plan is a mathematical foundation, not end-to-end inspection acceptance.
patterns-established:
  - Camera math uses Double construction and finite-checked Float matrices; independent scalar projection tests do not call production basis math.
requirements-completed: []
requirements-referenced: [INS-01, INS-02, INS-03, INS-04]
duration: approximately 15 min
completed: 2026-11-13
---

# Phase 8 Plan 01: Inspection Mathematical Foundation Summary

**Pinned inspection semantics, independent Double slice/tracer expectations, and bounded pure Swift camera values with full-aspect Metal projection.**

## Performance

- **Duration:** approximately 15 min, including context/reference reading; an exact start timestamp was not captured.
- **Started:** after the 19:14:26Z planning commit; first RED commit at 19:19:11Z.
- **Completed:** 2026-11-13, approximately 19:29Z.
- **Tasks:** 2/2.
- **Implementation/test/contract files:** 8 (plus this summary and subsequent scoped progress/config metadata).

## Accomplishments

- Froze world/plane/depth mappings, camera/guide/marker constants, finite-first tolerances, V[n+1] forward RK2 ordering, complete-resource inventory and paired-run/failure protocol before production inspection integration.
- Exported independent, deterministic JSON and little-endian Double seed expectations under `.build/inspection3d-reference`. Tests verify exact 512 i-fastest seeds/w lanes, all 12 plane/depth combinations, asymmetric affine/landmark values, equal 31/32 midpoint, six signed axis and two unequal combined trajectories, nonconstant affine RK2, 26 near-wall classes and 26 reflected wall/edge/corner classes. Contract corruption, nonfinite fixture generation, nonfinite binary data with recomputed hash, absent/malformed manifests, truncated payload and binary corruption are rejected.
- Added `InspectionPlane3D`, `CameraState3D`, `InspectionState3D`, `CameraFrame3D` and `Camera3D.frame`. Pure values have no evolution/Metal/AppKit ownership. Shared files belong exactly once to Mac, iOS and the direct-source Mac state-test target. No package, solver, renderer, UI or 2D ABI change was introduced.
- Checked 2,880 asymmetric scalar-reference projections across front/back/edge-on poses, elevation/zoom bounds, minimum/wide/tall viewports and 1×/2× sizes; checked default fit of every cube corner, Metal depth, upright basis, rotation-only guides, finite validation and distinct Reset Camera/Centre Slice scopes.

## Task Commits and TDD Evidence

All commits ran normally, without `--no-verify`; no hook failure occurred.

| Task | RED | GREEN | Review hardening |
|---|---|---|---|
| 1: Contract / independent expectations | `99b1ad8` | `dd43a72` | `43e1c91`, `00c7c63` |
| 2: Production values / camera math | `86f2deb` | `b7644df` | `00c7c63` |

1. `python3 -m unittest Tests.Integration.test_inspection3d_reference.InspectionReferenceTests.test_contract_and_oracle` first exited 1 with **AssertionError: preregistered inspection contract missing**. After contract/oracle implementation it exited 0: 1 test, 3.225 s; compile 3.185 s and run/checks 0.038 s.
2. `python3 -m unittest Tests.Integration.test_inspection3d_state.InspectionState3DChecks.test_camera_and_slice_state` first exited 1 with **AssertionError: production inspection value/math missing: InspectionState3D.swift**. After implementation and test-harness corrections the combined task command passed 2/2 in 2.550 s (state compile 1.294 s/run 0.008 s; oracle compile 1.212 s/checks 0.036 s).
3. Distinct inline review added nonconstant/wall trajectory checks. That run failed on missing `wallTrajectories`, then passed after the independent oracle export was expanded. This review was performed inline, not by an independent agent.

## Final Verification

### Focused commands

```sh
python3 -m unittest Tests.Integration.test_inspection3d_state Tests.Integration.test_inspection3d_reference Tests.Integration.test_fluid3d.Fluid3DTests.test_evidence_schema Tests.Integration.test_fluid3d.Fluid3DTests.test_volume_kernels_read_only_solver_status
```

**PASS:** 4/4, 2.955 s. Production compile 1.503 s / run 0.008 s; independent oracle compile 1.351 s / run and negative checks 0.068 s. This measured focused loop is under 30 s; it does not represent full GPU/Xcode/UI feedback latency.

### App builds (no Swift/deployment overrides)

```sh
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

**PASS:** both `BUILD SUCCEEDED`, exit 0, repeated after final source hardening. Final incremental wall times: Mac 3.714 s; iOS 3.107 s. Logs: `.build/inspection3d-state/mac-build-final.log` and `ios-build-final.log`. Metadata extraction warns that no AppIntents dependency exists; first iOS build also reported the inherited UIRequiresFullScreen deprecation. No warning was hidden or treated as a new inspection error.

```sh
xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO -only-testing:FluidDynamicsMetalStateTests
```

**PASS:** 25/25, zero failures; command 6.404 s, XCTest 0.422 s including suite overhead. This run preceded the explicit default-initializer hardening; the final production pure tests and both app builds were rerun afterward. Log: `.build/inspection3d-state/mac-state-tests.log`.

Additional acceptance gates: plutil-converted project graph verified exactly one membership for both shared files in all three targets; source ownership checks found no Metal/AppKit/evolution resources; `git diff --check` passed. The existing evidence-schema/read-only-kernel guards passed (these are not actual new GPU acceptance).

### Contract integrity

- Inspection whole-document SHA-256: `7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7` (pinned in both independent Swift and Python).
- Phase 7 whole-document SHA-256: `5fdc33b839d7f135a828ac9e6e3c3b4e7adba03d5341771ddbed4b13767951a8`.
- Phase 7 pinned prefix SHA-256: `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`.
- Both Phase 7 digests were independently recomputed; `git diff --exit-code -- docs/3d-numerical-contract.md` passed. No Phase 7 bytes changed.

## Inline Review Against Original Plan

Checked every task behavior/action/acceptance clause and plan success criterion against the final sources and actual commands. Findings addressed: constant velocities alone cannot distinguish Euler/RK2 (added analytic affine trajectory plus independent wall recurrence); malformed exports needed exercised rejection (added negative cases); synthesized memberwise initialization could bypass validation (explicit default initializers). All owned mathematical prerequisites pass. Runtime presentation/complete evolution-state preservation remains future integration evidence, not something these values can prove.

## Deviations from Plan

- **[Rule 2 — missing critical] Review-strengthened oracle and construction invariants.** Added explicit malformed-output cases, nonconstant RK2 and all near-wall classes, and sealed memberwise initialization (`43e1c91`, `00c7c63`). No new feature or acceptance relaxation.
- During GREEN, fixed a test-side Float/Double call mismatch and explicit `CGSize` invalid-fixture typing. A fixed 3e-5 tolerance at a constructed near-plane point failed from Float world-point/matrix cancellation. The near/far endpoint test now derives a rounding budget `32*Float.ulpOfOne*far/near`; asymmetric volume projections retain 3e-5, all default-fit/depth bounds remain mandatory, and no contracted GPU/numerical threshold changed.
- The summary template says to copy requirements into `requirements-completed`; the explicit plan/user instruction forbids completion from foundation tests. Kept it empty and recorded all four IDs in `requirements-referenced`; REQUIREMENTS.md is unchanged.
- Named executor definition is unavailable; workflow/reference protocol was followed inline as requested. No delegation, branch switch or worktree was attempted. The approved existing `workflow.use_worktrees=false` config change is preserved for the subsequent progress metadata commit.

## Issues Encountered

Only the resolved test-harness type/cancellation issues above. No authentication/human checkpoint or external setup was required. No exact wall-clock start timestamp was recorded, so duration is explicitly approximate.

## Next Phase Readiness and Residual Limits

- Ready for **08-02 / Wave 2**; only **1/9** Phase 8 plans is closed. No other wave executed.
- INS-01/02/03/04 and CTRL-08 remain pending. No new production GPU slice/tracer, renderer routing, complete-state independence, UI/HUD/human review or full integration regression run is claimed here. The selected supplemental Mac state tests and source/schema guards are the fresh regression evidence for this isolated foundation.
- No significant directory/dependency/module structural change: historical codebase maps were not rewritten for two same-pattern shared files.
- Phase 7 manual review remains unperformed; actual macOS26 and physical-device multitouch **NOT TESTED**; displayed pacing **NOT MEASURED**. The future 08-09 human checkpoint remains blocking and unapproved.

## Self-Check: PASSED

All seven new implementation/test/contract paths and project memberships exist; task commits are present; both task acceptance gates and plan-level focused/build commands passed. Phase requirements were not completed. Summary is committed before STATE/ROADMAP updates per the atomic closeout invariant.

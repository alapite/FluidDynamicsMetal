---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: 3D Teaching Foundation
status: executing
stopped_at: Completed 08-04-PLAN.md; next 08-05 / Wave 5
last_updated: "2026-11-14T11:23:50Z"
last_activity: 2026-11-14 -- 08-04 / Wave 4 complete; next 08-05 / Wave 5
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 18
  completed_plans: 13
  percent: 25
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-11-06)

**Core value:** People can interact with a responsive, visually familiar fluid simulation on both supported platforms and adjust it without editing source code.
**Current focus:** Phase 08 — spatial-inspection

## Current Position

Phase: 08 (spatial-inspection) — IN PROGRESS
Plan: 4 of 9 complete; next 08-05 / Wave 5
Status: Ready to execute next plan; Phase 8 acceptance pending
Last activity: 2026-11-14 -- 08-04 / Wave 4 complete; next 08-05 / Wave 5

Progress: [███████░░░] 72% of currently planned v1.1 plans closed (13/18); Phase 8 is 4/9. No v1.1 phase is fully accepted; Phase 7 manual acceptance remains incomplete.

## Performance Metrics

**Velocity:**

- Total plans completed: 27 (14 archived v1.0 + 13 current v1.1)
- Average duration: N/A (historical plan durations not fully aggregated)
- Total execution time: At least 5.2 hours across recorded v1.1 Phase 7 plans; archived v1.0 duration is excluded.

**By Phase:** v1.0 implementation plans 14/14 archived; Phase 7 plans 9/9 closed. Phase 7 user-facing acceptance remains incomplete because manual review was not performed; VER-03 is complete from automated evidence. Historical macOS 26 and device-only verification remain deferred.

**Recent Trend:** Phase 8 Wave 4 native Mac controls/gesture UI checks, both-target builds, and the spatial-slices/inspection-routing production fixtures passed. Light/Dark and Increase Contrast capture attachments are retained; VoiceOver and physical gesture direction/feel review remain pending, not accepted from screenshots.

## Accumulated Context

### Roadmap Evolution

- v1.1 approved 2026-11-06: Mac-first 64³ true-3D dye-advection lesson, orbit camera, slices, tracers, then basic volume rendering; phases continue at 7.
- v1.1 requirements approved: focused dye inspection, existing 600-step lesson contract, and measured 30 fps floor at 64³ / 1280×720 on a named reference Mac. Research and roadmap review performed inline.
- v1.0 phase histories are archived under `.planning/milestones/v1.0-phases/`; their deferred verification remains open.
- Post-v1.0 educational features were delivered outside the GSD phase sequence; `docs/educational-release-verification.md` records the 2026-10-13 baseline.
- Phase 6 edited: repurposed Phase 6 for macOS 26 and iOS/iPadOS 26 compatibility verification; deferred CTRL-05/06/07 to v2

### Decisions

- Modernize both targets for macOS 26 / Apple Silicon and iOS 26; preserve the familiar fluid behavior.
- Introduce native UI controls and tuning with reset-on-launch defaults.
- Xcode 27 Device Hub two-finger touch simulation is unavailable ([developer forum report](https://developer.apple.com/forums/thread/846533)); retain device-only checks as NOT TESTED but do not gate later phases or milestone completion on them (user decision, 2026-09-25).
- 2026-11-07: User approved compensated high/low Float32 pressure and a separately derived storage/evaluator identity-rounding bound while retaining strict Double ideal identity, both 1e-5 residual/divergence gates, 1000x reduction, cap 320 and fixture amplitudes. See the appended amendments in `docs/3d-numerical-contract.md`.
- 2026-11-08: Phase 7 Plan 07-06 commits 3D renderer mode only after candidate reset/status validation; exact encode-before-consume steps use asynchronous completion diagnostics and generation-fenced recovery. The established 2D solver/ABI remains unchanged; phase requirements stay pending until end-to-end UI/lesson verification.
- 2026-11-13: 08-01 pins inspection contract SHA-256 `7f793d4ecfff13e7138a96e354f7597a9da9db88853c657d47a23ae09955e0c7`; pure validated values/matrices own no evolution resources. Explicit initializers seal validation; slider yaw clamps while gesture yaw wraps. No requirements completed from foundation tests.
- 2026-11-13: 08-02 adds a read-only, depth-equipped spatial sheet and projected cube guide while preserving `encodeSlice` and the 2D solver/ABI. Spatial GPU evidence uses the pinned independent inspection contract and stays separate from historical benchmark evidence. INS-01/02/04 remain pending until interactive app integration and user-facing acceptance.
- 2026-11-14: 08-03 separates inspection edits from evolution state, routes paused presentation through a no-advance draw path, and distinguishes Restart retention from explicit 3D-entry defaults. Depth resources are preflighted transactionally; 3D presentation uses actual drawable dimensions. No 2D solver or ABI changes.
- 2026-11-14: 08-04 adds native plane/depth/camera controls, a hit-transparent rotation-following orientation guide, and canvas-owned paused orbit/zoom. Panel-originated keys/gestures stay separate; screenshots are evidence only. Phase 8 requirements remain pending until later plans and human acceptance.

### Pending Todos

- Optional follow-up when convenient: work through the unchecked manual-review checklist in `docs/3d-phase7-verification.md` and record actual observations. Until then, keep SIM-04, SIM-05, SIM-06, LES-01, LES-02, and LES-06 pending manual acceptance.
- Phase 8 Plan 08-04 manual follow-up: perform VoiceOver review and physical mouse/trackpad direction/feel checks when available; screenshots and synthesized events are not substitutes.

### Blockers/Concerns

- At the 08-01 closeout: actual RED/GREEN for both tasks; independent Double oracle and 2,880 production projection checks pass, both no-override app builds pass, selected Mac state tests 25/25 and existing schema/read-only guards pass. Final focused four-test command took 2.955 s including compilation. Distinct inline review strengthened nonconstant RK2/wall cases and malformed-output checks. No new GPU/UI/HUD/full integration or human acceptance was claimed. Next was 08-02 / Wave 2; 08-09 remains blocking. Sequential current-checkout execution used the user-approved `workflow.use_worktrees=false`.
- 08-02 / Wave 2 closed: asymmetric spatial sampling passed 24 samples across three planes/four depths, backside and edge-on projections, all 12 cube edges, 1×/2× stroke scaling, viewport/input guards, exact ping/pong immutability, depth/pipeline reuse, and injected allocation failures. Fresh Mac and iOS Simulator builds and spatial, legacy slice/palette, and evidence-schema fixtures passed. See `08-02-SUMMARY.md` and the scoped inline `08-REVIEW.md`. No UI integration or user-facing requirement is complete; next is 08-03 / Wave 3, and 08-09 remains blocking.
- 08-03 / Wave 3 closed: state-scope checks, the production inspection-routing fixture, existing renderer step/inactivity and transition/failure fixtures, and both established renderer harnesses passed (10 tests total). Fresh Mac and iOS Simulator builds passed. See `08-03-SUMMARY.md`; no later Phase 8 plan ran, all five Phase 8 requirements remain pending, and 08-09 remains the blocking human checkpoint.
- 08-04 / Wave 4 closed: the full Mac state/HUD suite passed (25 state + 19 UI tests), both no-override app builds passed, and the spatial-slices and inspection-routing production fixtures passed. Light/Dark and Increase Contrast UI capture bundles are retained. VoiceOver, physical gesture direction/feel, and macOS 26 runtime remain NOT TESTED; no Phase 8 requirement is complete. See `08-04-SUMMARY.md`. Next is 08-05 / Wave 5; no later plan or phase-level verification ran.
- Phase 8 has nine executable plans / nine sequential waves / seventeen tasks. Distinct inline plan review passed after correcting early standalone-source dependencies and active-failure Free Play recovery/copy. All five owned requirements and D-01–21 are covered; schema/structure/XML/dependency/decision checks passed. See `08-PLAN-CHECK.md`. No Phase 8 implementation, app build/test, GPU evidence, measured feedback latency or human acceptance was performed during planning. Plan 08-09 is a blocking future human-review checkpoint; no prior no-issues assumption auto-approves it.
- Phase 6 VER-02 is verified on the available macOS 27 host and iOS 26.4 simulators. The user approved closing v1.0 on 2026-09-25 while deferring actual macOS 26 runtime launch/drag beyond this milestone; PLAT-01 remains NOT TESTED and unverified.
- Phase 6 iPhone and iPad HUD UI-test runs timed out without results; they remain NOT TESTED for this run. The user approved the separate manual checklist on the three prepared targets.
- Xcode 27.0 Metal Toolchain 27A266a installed. The Mac target builds for arm64 with a macOS 26.0 minimum on this macOS 27 host.
- `./build-macos.sh` places a reusable Debug build at the project root as `FluidDynamicsMetalOSX.app` for phase closeout testing.
- The user confirmed visual drag/Space/S behavior on macOS 27. Actual macOS 26 runtime launch and drag remain NOT TESTED for future follow-up; a macOS 26 VM with a usable Metal device is a possible test host.
- Tart's interrupted image download restarted at 0%; if the macOS 26 runtime check is reprioritized, use the resumable `curl -C -` command in `01-BASELINE.md`. A partial macOS 26.6.2 IPSW is retained under ignored `.build/`.
- GSD researcher and roadmapper agent definitions are unavailable in this runtime; initial research and roadmap were produced inline.
- Phase 7 UI-SPEC remains approved (five PASS, one non-blocking inherited-spacing FLAG). Nine executable plans / eight waves / 20 tasks pass inline plan review and structural/coverage checks: all seven owned requirements and D-01–17 covered. Pattern mapping and executable validation strategy are saved. No implementation, app build, numerical test, benchmark or human acceptance was performed during planning.
- Active Xcode 27.2 initially lacked its Metal Toolchain; Metal Toolchain 27.2 was subsequently installed/rechecked and used for the 07-02 builds and production GPU evidence on 2026-11-07.
- At the 07-03 checkpoint, Plan 07-03 was merged into master and post-merge verified: all seven GPU projection families, independent readback gates, explicit failure/queued-session checks and the strengthened 600-step finite soak passed; 23 integration tests and both app builds passed, plus 34 Mac state/HUD tests before and after merge. At that point all Phase 7 requirements remained pending until end-to-end lesson/UI verification.
- Phase 7 Plan 07-04 is merged into master and post-merge verified: both app builds, all 25 integration regressions, 34 Mac state/HUD tests, the iPhone iOS 26.4 HUD suite (11/11), and the iPad iOS 26.3 HUD suite (11/11) passed. The iPad Pro 13-inch M5 / iOS 26.4 simulator run had 6/11 pass and five orientation-wait failures at `Tests/UI/iOS/HUDUITests.swift:137`; this unrelated simulator/test diagnostic is recorded, with no UI changes. At that checkpoint four plans remained, next 07-06 / Wave 5.
- At the 07-06 checkpoint, Plan 07-06 was merged into master and post-merge verified: both no-override app builds passed, Mac state tests passed (25/25), and all 27 integration tests passed, including 3D renderer transition/step/inactivity fixtures and existing 2D renderer/educational regressions. Plans 07-07 through 07-09 and phase acceptance were still pending at that checkpoint.
- At the 07-07 checkpoint, Plan 07-07 was verified: all six focused 3D Mac HUD tests passed; full Mac HUD suite 15/15 and state suite 25/25 passed; both no-override app builds passed; all 27 integration tests passed. Narrow-width wrapping has a Debug-only test override and UI regression. Light/Dark and Simulation-menu screenshot attachments are retained in the full UI `.xcresult`. Manual visual/accessibility review was pending for 07-09; actual macOS 26 and physical-device checks remained NOT TESTED. The next plan was 07-08 / Wave 7.
- At the 07-08 checkpoint, Plan 07-08 was verified: benchmark/evidence schema, production fixtures, no-override builds, Mac state/HUD (40/40), full integration (28/28), and final iPhone/iPad HUD suites (11/11 each) passed. Initial iPhone 9/11 and iPad 8/11 orientation/fade outcomes and successful focused/full retries are preserved in `.build/fluid3d-evidence/regression-matrix.json`. The 64³ M3 Pro solver-only and solver-plus-fixed-slice GPU medians are 161.410/317.521 ms; this is offscreen timing, not FPS. See `docs/3d-phase7-verification.md` and `07-08-SUMMARY.md`. Manual acceptance remained pending for 07-09; macOS 26 runtime and physical multitouch remained NOT TESTED.
- Phase 7 Plan 07-09 documentation closeout is recorded after the user said they cannot commit to manual checks and directed us to proceed assuming no issues. The report retains an unchecked manual checklist and explicitly records that no visual/accessibility/interaction checks or observations were made; this is not a human-review PASS. Six user-facing Phase 7 requirements remain pending, VER-03 is complete on automated production-kernel evidence, actual macOS 26 and physical-device multitouch remain NOT TESTED, and displayed frame pacing remains NOT MEASURED. All nine plans are closed; phase-level user-facing acceptance is incomplete.
- The 64³ wall/edge/corner pressure stress case converged at 317/320 iterations, leaving only three iterations of cap margin. This is measured numerical evidence, not a performance or cross-device guarantee. No cap or primary acceptance threshold was relaxed.
- Phase 3 inline code review `03-REVIEW.md` records an advisory resample-pipeline failure-path warning; successful Mac/iOS user interaction and current GPU tests do not exercise that negative path.

## Deferred Items

The 2026-09-25 pre-close audit found three open artifacts (Phase 1 UAT and verification; Phase 2 partial UAT). The user acknowledged these for v1.0 closure: macOS 26 runtime is deferred, and device-only iOS multitouch was already non-blocking. Open statuses stay visible until actual verification occurs.

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| UX | Saved presets, image/recording export | v2 | Initialization |
| Verification | Phase 1 macOS 26 launch and drag (`01-HUMAN-UAT.md`, PLAT-01) | NOT TESTED — explicitly deferred beyond v1.0, non-blocking for close | 2026-09-25, user-approved |
| Verification | Phase 2 two-finger gesture and concurrent-touch observations (`02-HUMAN-UAT.md`) | NOT TESTED — device-only; non-blocking for further phases and milestone completion | 2026-09-24, clarified 2026-09-25 by user |
| Verification | Phase 3–4 iPhone/iPad two-finger field cycling and HUD/concurrent-touch observations (`03-STATE-VERIFICATION.md`, `04-HUD-VERIFICATION.md`) | NOT TESTED — Device Hub limitation; physical-device follow-up, non-blocking for further phases and milestone completion | 2026-09-25, user-approved |
| Phase 03 P01 | 12 min | 2 tasks | 7 files |
| Phase 03 P02 | 12 min | 2 tasks | 6 files |
| Phase 03 P03 | 10 min | 2 tasks | 2 files |
| Phase 04 P01 | 5 min | 2 tasks | 4 files |
| Phase 04 P02 | 4 min | 2 tasks | 1 files |
| Phase 04 P03 | 11 min | 2 tasks | 2 files |
| Phase 05 P01 | 10 min | 2 tasks | 8 files |
| Phase 05 P02 | 19 min | 2 tasks | 2 files |
| Phase 05 P03 | 6 min plus human checkpoint | 2 tasks | 3 files |
| Phase 06 P01 | 33 min | 3 tasks | 3 files |
| Phase 07 P01 | 40 min | 2 tasks | 4 files |
| Phase 07 P05 | 21 min | 2 tasks | 5 files |
| Phase 07 P02 | 60 min | 2 tasks | 9 files |
| Phase 07 P03 | 60 min including closeout | 3 tasks | 11 implementation/test/contract files |
| Phase 07 P04 | at least 46 min | 2 tasks | 7 implementation/test files |
| Phase 07 P06 | approximately 90 min including post-merge verification | 3 tasks | 8 implementation/test files |
| Phase 08 P01 | approximately 15 min | 2 tasks | 8 files |
| Phase 08 P02 | 65 min | 2 tasks | 4 files |

## Session Continuity

Last session: 2026-11-14T11:23:50Z
Stopped at: Completed 08-04-PLAN.md; next 08-05 / Wave 5
Resume file: .planning/phases/08-spatial-inspection/08-05-PLAN.md

## Operator Next Steps

- Continue with 08-05 / Wave 5 only when authorized. Read `08-04-SUMMARY.md` for native controls, gesture routing, capture evidence, and pending manual checks; read `08-03-SUMMARY.md` for renderer routing/state scopes, `08-02-SUMMARY.md` for the spatial renderer API, and `08-01-SUMMARY.md` for the foundation API and pinned contract. Four of nine plans are complete; no later plan or phase-level verification ran. All Phase 8 requirements remain pending.
- No remaining Phase 7 plans. When convenient, the user may complete the unchecked manual-review checklist in `docs/3d-phase7-verification.md`; record only actual observations. Do not treat the user-directed no-issues assumption as visual/interaction approval. Keep the six user-facing requirements pending; actual macOS 26 runtime and physical-device checks remain NOT TESTED, and displayed frame pacing remains NOT MEASURED.

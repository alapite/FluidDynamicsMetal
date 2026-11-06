---
phase: 3
slug: reliable-simulation-state
status: partial-automated-coverage
nyquist_compliant: false
wave_0_complete: true
created: 2026-09-24
---

# Phase 3 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest macOS unit target for production shared state; Python `unittest` + offscreen Metal harness for resize; manual Mac/iOS UI observations |
| **Config file** | `FluidDynamicsMetal.xcodeproj/project.pbxproj` and shared Mac scheme (Wave 1 creates test target); `test_phase03_metal.py` and `test_phase03_metal.swift` (Wave 2) |
| **Quick run command** | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` |
| **Full suite command** | Quick run; `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build`; `python3 -m unittest -v test_phase02_metal test_phase03_metal`; manual UI observations |
| **Estimated runtime** | XCTest and two builds depend on caches (~1–4 minutes); Metal harness ~15 seconds; manual UI ~5 minutes per layout |

## Sampling Rate

- **After each Wave 1 state task:** run the XCTest quick command (after the test target exists).
- **After the resize shader task:** run both Mac Debug build and `python3 -m unittest -v test_phase03_metal`; after controller integration run both scheme builds.
- **After each wave:** run the full automated suite relevant to files edited; record any blocked simulator/manual observations separately.
- **Before `/gsd-verify-work`:** state tests, GPU resize check and both builds green; manual resize/drag/pause/field/inactivity behavior actually observed or marked untested.
- **Max feedback latency:** one incremental Xcode test/build plus the offscreen GPU check per affected task; no watch-mode command.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | SIM-03, VER-01 | — | Bounded finite tuning, no delayed input after pause | XCTest | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` | ✅ | COVERED: 5 passing state tests; all six mutated tuning values reset |
| 03-01-02 | 01 | 1 | SIM-03, VER-01 | — | Paused field switch renders without advancing, iOS lifecycle restores user intent | XCTest + both app builds + manual UI | Same test; both Debug scheme builds | ✅ | PARTIAL: state tested, Mac UI previously observed; paused GPU render and iOS field gesture not automated |
| 03-02-01 | 02 | 2 | SIM-02 | — | Existing GPU fields survive aspect changes | GPU + Mac build + manual UI | `python3 -m unittest -v test_phase03_metal` after Mac Debug build | ✅ | PARTIAL: 5 seeded fields pass both aspect directions; renderer migration not tested end-to-end |
| 03-02-02 | 02 | 2 | SIM-02, SIM-03 | — | Held input rebases; no stale forces across resize | both scheme builds + GPU + manual UI | Mac/iOS Debug builds; `python3 -m unittest -v test_phase03_metal` | ✅ | PARTIAL: controller input rebasing was user-observed, not automated |
| 03-03-01 | 03 | 3 | SIM-02, SIM-03, VER-01 | — | No untested behavior reported as passed | full suite + observation record | XCTest; both builds; `python3 -m unittest -v test_phase02_metal test_phase03_metal` | ✅ | COVERED as evidence recording: 5 XCTest + 2 Metal checks pass; UI limitations below |

## Requirement Coverage (2026-09-25 Audit)

| Requirement | Automated evidence | Classification | Remaining gap |
|-------------|--------------------|----------------|---------------|
| VER-01 | `FluidDynamicsMetalStateTests/SimulationStateTests.swift`: five passing tests covering bounds, defaults, reset of every mutated tuning value, four fields, pause and inactive return | COVERED | — |
| SIM-02 | `test_phase03_metal.py` / `test_phase03_metal.swift`: built shader resamples five distinct seeded fields, corner/center RG16F values and velocity scaling in 64×32→32×96 and 32×96→64×32 | PARTIAL | Live renderer texture migration and controller input rebasing rely on recorded user observations, not automated app integration tests |
| SIM-03 | Production-state XCTest verifies field/pause/inactivity transitions; paused Mac rendering and available iOS interaction were previously observed | PARTIAL | Solver-free presentation, stale input clearing and iOS two-finger field selection are not automated; two-finger gesture remains NOT TESTED on simulators |

## Wave 0 Requirements

- [x] Add shared production `SimulationState.swift`, Mac unit-test target and shared scheme TestAction, and `SimulationStateTests.swift` in Plan 01 before claiming VER-01.
- [x] Add `test_phase03_metal.py` and `test_phase03_metal.swift` in Plan 02; seed nonuniform test textures and read back actual GPU resample output.
- [x] Xcode Metal Toolchain available; iPhone 17 Pro and iPad Pro 13-inch M5 iOS 26.4 simulators launched.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fluid visible and responsive during/after live Mac resize, including held mouse drag | SIM-02 | Offscreen shader cannot exercise window events | Stir blue density, drag window edges through major aspect ratio change while stirring, confirm entire existing pattern fits and first resumed input does not jump; recheck Space/S. |
| iPhone/iPad rotation or view resize and new touch responsiveness | SIM-02 | Simulator device layout + gesture path beyond shader harness | Stir on both layouts, rotate or resize view, confirm same fluid fits and fresh touch stirs; record touch-during-rotation result where reproducible. |
| Paused field switch/resize without solver motion | SIM-03 | Unit state checks do not certify presented frame | Pause with Space or double tap, cycle all fields, resize and confirm frozen adapted fluid and immediate selected-field presentation; resume and drag. |
| Brief iOS background/foreground preserving field and pause intent | SIM-03 | Lifecycle notification/UI interaction is not driven by state unit test | With running and manually paused cases, send simulator Home/return, confirm field and fluid persist with no catch-up, then fresh touch stirs; record untestable physical-device cases separately. |
| iOS two-finger field selection and physical simultaneous touches | SIM-03 | Not reproducible on the available simulators; no physical-device observation | On physical iPhone and iPad, pause with one-finger double tap, cycle all four fields using two-finger double tap, resume and confirm new and concurrent touches stir without stale impulses; record device/version in `03-STATE-VERIFICATION.md`. |
| Renderer resize failure and paused render-only integration | SIM-02, SIM-03 | State/shader checks do not exercise render-pipeline creation failure or prove solver passes are skipped in an app frame | Exercise repeated resize while paused and verify no solver motion; investigate pipeline failure handling in `03-REVIEW.md` (WR-01) before treating failed migration as safe. |

## Validation Sign-Off

- [x] Each task has `<verify><automated>` or depends on Wave 0 tests created by a preceding task; 03-03-02 has an additional human gate.
- [x] No three consecutive tasks without an automated test/build command.
- [x] Wave 0 test target and GPU harness run against production code rather than duplicate state/shader logic.
- [x] Both schemes compiled in Plan 03; this audit reran Mac XCTest (5/5) and the two offscreen Metal checks (2/2); prior device observations remain recorded in `03-STATE-VERIFICATION.md`.
- [x] No watch-mode flags; `nyquist_compliant: false` reflects partial end-to-end automation despite green state/shader checks.

**Approval:** user approved Mac and iPhone/iPad simulator interactions on 2026-09-25; two-finger gestures remain NOT TESTED because the simulator could not reproduce them. This audit did not repeat those manual observations. See `03-STATE-VERIFICATION.md`.

## Validation Audit 2026-09-25

| Metric | Count |
|--------|-------|
| Gaps found | 4 |
| Resolved | 2 |
| Escalated to manual-only/integration follow-up | 2 |

Added a fifth production-state XCTest for pause changes during inactivity and extended reset assertions to all six mutated tuning values. Expanded the offscreen built-metallib test to verify five independently seeded RG16F fields in both aspect-change directions. `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` ran 5/5 passing tests; `python3 -m unittest -v test_phase02_metal test_phase03_metal` ran 2/2 passing tests. Renderer/controller integration remains manual-only; the pipeline-failure issue is tracked as WR-01 in `03-REVIEW.md`. Typed Nyquist auditor dispatch was unavailable; audit was performed inline.

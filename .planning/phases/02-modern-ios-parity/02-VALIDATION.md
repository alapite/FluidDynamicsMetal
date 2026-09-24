---
phase: 2
slug: modern-ios-parity
status: audited-partial
nyquist_compliant: false
wave_0_complete: true
created: 2026-09-24
---

# Phase 2 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Xcode 27 `xcodebuild` builds, Python 3 `unittest` bundle/simulator smoke tests, and human interaction checks; no XCTest target |
| Config file | `FluidDynamicsMetal.xcodeproj/project.pbxproj`; `test_phase02_bundle.py` |
| Quick run command | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build` |
| Full suite command | Quick iOS build; `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build`; `python3 -m unittest -v test_phase02_bundle`; then manual gesture/visual checks |
| Estimated runtime | Builds vary with local caches; simulator smoke test ~1 minute; manual checks ~5 minutes per layout |

## Sampling Rate

- **After each source-change task:** Run the iOS Debug build without a deployment override. After each `Shared/` edit, also run the Mac Debug build.
- **After each wave:** Check iOS bundle `MinimumOSVersion=26.0`, `default.metallib`, and no Swift 4 effective setting, then run iPhone and iPad simulator checks when runnable.
- **Before `/gsd-verify-work`:** Both builds green; iPhone and iPad observations recorded; physical multi-finger behavior is explicitly `NOT TESTED` if simulator cannot establish it.
- **Max feedback latency:** One incremental iOS build per edit; hardware-dependent visuals use an end-of-wave manual checkpoint.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | PLAT-02, PLAT-03, SIM-01 | — | iOS bundle requires Metal-capable device; no external data | build + bundle smoke | iOS Debug build; `python3 -m unittest -v test_phase02_bundle` | ✅ `test_phase02_bundle.py` | ✅ build/bundle/launch; interaction manual |
| 02-01-02 | 01 | 1 | PLAT-02, PLAT-03 | — | simulator bundle has Metal library | bundle + Mac build | Mac Debug build; `python3 -m unittest -v test_phase02_bundle` | ✅ `test_phase02_bundle.py` | ✅ covered |
| 02-02-01 | 02 | 2 | SIM-01 | — | bound input slots and deterministic touch lifetime | build + state inspection | iOS Debug build and Mac Debug build after `Shared/` changes | ✅ source | ◐ partial: no automated touch-state test; physical multi-touch untested |
| 02-02-02 | 02 | 2 | SIM-01, PLAT-02 | — | gesture shortcuts do not inject stale splats | build + simulator | iOS Debug build; simulator gesture observation is manual | ✅ source | ◐ partial: one-finger observed; two-finger untested |
| 02-03-01 | 03 | 3 | PLAT-02, PLAT-03, SIM-01 | — | evidence distinguishes tested and untested device behaviors | bundle + simulator | Both Debug builds; `python3 -m unittest -v test_phase02_bundle` | ✅ `test_phase02_bundle.py` | ◐ partial: automated launches; visual checks manual |

## Wave 0 Requirements

Existing Xcode project, schemes and iOS 26 simulator runtimes provide a build gate. `test_phase02_bundle.py` inspects the freshly built bundle and installs/launches it on available iOS 26 iPhone and iPad simulators. It cannot validate touch or GPU visuals. No XCTest target is present; Phase 3 introduces automated shared-state coverage. A missing Metal Toolchain must be installed with `xcodebuild -downloadComponent MetalToolchain` before build verification.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| iPhone and iPad black canvas / blue density, swirl and fade | PLAT-02, SIM-01 | GPU appearance cannot be certified by compile | Launch on both iOS 26 simulator device types, swipe, compare recognizable look to `01-BASELINE.md` and `FluidDynamicsMetal.gif`; record actual observations. |
| One-finger double-tap pause, two-finger double-tap cycle without dye | SIM-01 | Gesture sequencing requires UI input | Try supported simulator touch input; record observed result or `NOT TESTED` if gesture simulation cannot express it. |
| Multiple independent live fingers incl. lift/cancel | SIM-01 | Single mouse pointer is not physical multi-touch | Use simulator multi-touch if convincingly available; otherwise record `NOT TESTED — device-only` per D-11, without claiming device coverage. |
| Mac input parity | PLAT-03, SIM-01 | Compile does not prove mouse/keyboard response | Rebuild Mac and use `01-BASELINE.md`'s recorded macOS 27 interaction; only claim a *new* interaction pass if re-observed. macOS 26 host testing stays at milestone closeout. |
| Touch identity, >10 contacts, lift/cancel and stale-force prevention | SIM-01 | GPU-bound touch/Metal state has no separable test harness or XCTest target in this phase; build and static inspection do not prove behavior | Exercise simultaneous drags, overflow where hardware allows, and lifting/cancelling one finger on a physical device; confirm survivors continue and released contacts stop painting. Add automated shared-state tests in Phase 3. |
| Two-finger double-tap field cycle and clean density | SIM-01 | Not observed in the available simulator input session | Use a reliable two-finger input source; double-tap through all four fields and verify no dye blot. |
| iPhone/iPad proportional stroke width | SIM-01 | No observed side-by-side canvas-relative comparison | Compare stroke width as a fraction of the short canvas side on both devices. |

## Validation Sign-Off

- [x] Each planned code task has an automated build gate; built-bundle checks and fresh simulator launch are automated; visual/touch behavior has an explicit manual checkpoint.
- [x] Existing Xcode scheme and simulator are sufficient for wave 0; no test target is assumed.
- [x] No watch-mode flags; no claims that a build establishes runtime behavior.
- [x] Both Debug builds and two bundle/simulator smoke tests passed on 2026-09-24; previously observed manual cases are recorded in `02-PARITY.md`.
- [ ] Physical multi-touch, two-finger shortcut, proportional stroke and macOS 26 runtime are directly observed; SIM-01 is only partially verified.

**Approval:** Partial. `PLAT-02` and `PLAT-03` have repeatable build/bundle/launch checks; `SIM-01` retains manual-only interaction gaps.

## Validation Audit 2026-09-24

| Metric | Count |
|--------|-------|
| Gaps found | 2 requirements (PLAT-02 automated bundle/launch, SIM-01 interaction) |
| Resolved | 1 (PLAT-02 bundle and iPhone/iPad launch smoke test) |
| Escalated | 1 (SIM-01 touch/GPU behaviors need manual device checks or a future test harness) |

Both no-override scheme builds and `python3 -m unittest -v test_phase02_bundle` passed (2 tests). The smoke test does not turn an unobserved interaction into a pass.

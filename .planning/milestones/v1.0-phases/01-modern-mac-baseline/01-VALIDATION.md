---
phase: 1
slug: modern-mac-baseline
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-24
---

# Phase 1 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Xcode 27 `xcodebuild` for build verification; human GPU interaction check |
| Config file | `FluidDynamicsMetal.xcodeproj/project.pbxproj` (no test target yet) |
| Quick run command | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` |
| Full suite command | Quick build plus arm64/bundle minimum OS inspection and manual Mac drag/pause/field-switch check |
| Estimated runtime | Build duration depends on local Xcode cache; manual check ~2 minutes |

## Sampling Rate

- **After the project-setting task:** Run the quick build without a deployment-target override. Install Xcode's Metal Toolchain first if the build reports it missing.
- **After the plan wave:** Inspect the built arm64 executable, minimum OS and default Metal library; perform the manual GPU check.
- **Before `/gsd-verify-work`:** Build passes, reference document exists, and manual results are recorded.
- **Feedback latency:** One Mac build after each source change; no test target is introduced for this phase.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | PLAT-01 | — | Local app; no new external trust boundary | build | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` | ✅ | ✅ green |
| 01-01-02 | 01 | 1 | PLAT-01 | — | Baseline contains no credentials | source/bundle inspection | Inspect `01-BASELINE.md`, `lipo -archs` and `PlistBuddy` on the built app | ✅ | ✅ green |

## Wave 0 Requirements

Existing Xcode project and build command provide the automated gate. Optional Metal Toolchain installation is a prerequisite on hosts where `metal` is missing; it is not a repository test fixture.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mac fluid density and motion respond to drag | PLAT-01 | Metal pixels and pointer events require a desktop/GPU session | At phase closeout, launch built app, drag, release, observe visible density and continuing motion; record the observed result in `01-BASELINE.md`. Screenshot optional; no recording permission required. |
| App runs on actual macOS 26 | PLAT-01 | Current host runs macOS 27 | Launch and repeat drag on macOS 26 hardware/VM; record OS/build and outcome. A macOS 27 pass alone does not prove 26 runtime. |
| Existing pause and field-cycle interactions | PLAT-01 | Verifies baseline for later parity | Press Space twice, press S four times, note density/pressure/velocity/vorticity appearances. |

## Validation Sign-Off

- [x] Each automated task has a build or source/bundle check; manual checks have a blocking checkpoint.
- [x] No three consecutive tasks lack an automated check.
- [x] No missing test infrastructure is mistaken for a phase requirement.
- [x] No watch-mode flags.
- [x] Build and bundle evidence collected during execution.
- [x] Drag/pause/field-selection observed by the user on macOS 27 and recorded in `01-BASELINE.md`.
- [ ] Actual macOS 26 runtime launch/drag evidence collected.

**Approval:** Manual interaction confirmed on macOS 27; macOS 26 runtime sign-off remains pending.

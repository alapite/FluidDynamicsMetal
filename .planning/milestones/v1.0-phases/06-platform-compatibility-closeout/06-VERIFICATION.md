---
phase: 06-platform-compatibility-closeout
verified: 2026-09-25
status: passed
score: 3/3 phase goal criteria supported within approved available-host scope
---

# Phase 06 — Platform compatibility closeout verification

**Goal:** Developers can build and verify the existing fluid apps for macOS 26 on Apple Silicon and iOS/iPadOS 26, with repeatable platform-specific instructions and no new controls or solver behavior.

## Goal Achievement

| Phase criterion | Status | Evidence |
|-----------------|--------|----------|
| Both schemes build without deployment-target or Swift-version overrides | PASS for build compatibility on the available host | Exact no-override Mac arm64 and generic iOS Simulator Debug commands returned `BUILD SUCCEEDED` on arm64 macOS 27.0 / Xcode 27.0. The root Mac app executable is arm64, its minimum OS is 26.0 and it contains `default.metallib`. The built iOS simulator app reports minimum OS 26.0 and contains `default.metallib`. The macOS 26 **runtime** is separately unverified. |
| Repeatable Mac, iPhone and iPad default, drag, pause/resume, field and existing tuning steps | PASS for documentation and broad user-reported available-host walkthrough | `README.md` has separate numbered checklists, exact scheme names, Force/Dye/Swirl/Fade defaults, four named fields, outside-HUD drag, shortcuts and relaunch defaults. `AGENTS.md` reflects Swift 5/macOS 26/iOS 26 and the actual test targets. User replied “All tests pass on all targeted devices” to the Phase 06 manual-checklist request on the prepared macOS 27 Mac, iOS 26.4 iPhone 17 Pro simulator and iOS 26.4 iPad Pro 13-inch (M5) simulator. The reply was broad rather than a per-step log. |
| Verification identifies actual host and preserves outstanding OS/device-only checks | PASS | `06-COMPATIBILITY-VERIFICATION.md` separates builds, bundle inspection, process launches, automated tests and user-reported visual checks, naming host, OS, Xcode and simulator. The pending macOS 26 runtime check links `01-BASELINE.md` and `01-HUMAN-UAT.md`; physical-device two-finger/concurrent touches remain NOT TESTED and non-blocking. |

## Requirements and Artifacts

| Requirement | Plan, summary and implementation evidence | Result |
|-------------|-------------------------------------------|--------|
| VER-02 | `06-01-PLAN.md` lists VER-02, `06-01-SUMMARY.md` records it, `README.md` covers both schemes and all three manual procedures, `AGENTS.md` matches actual project settings and tests, `06-COMPATIBILITY-VERIFICATION.md` records independently attributed outcomes | PASS within the agreed available-host scope. |

No resolution, in-app reset or further accessibility capability was added or promised. CTRL-05/06/07 remain deferred to v2.

## Automated Checks and Regression

- Fresh Mac `xcodebuild ... build` and `./build-macos.sh`: successful on arm64 macOS 27.0 / Xcode 27.0. Fresh generic iOS Simulator Debug build: successful. Neither is a macOS 26 runtime check.
- Mac `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`: 11 state/renderer-contact and 5 HUD UI cases, 0 failures. Post-plan `xcodebuild -quiet ... build` and `xcodebuild -quiet test ...` also returned exit 0. The Mac build/tests include unrelated pre-existing uncommitted controller/UI-test workspace changes.
- `python3 -m unittest test_phase05_metal.py`: 1/1 OK after the fresh Mac build. Prior-phase regression `python3 -m unittest -v test_phase02_settings test_phase02_bundle test_phase02_metal test_phase03_metal`: 5/5 OK (includes fresh iPhone/iPad bundle launch checks).
- iPhone and iPad iOS 26.4 **HUD UI test invocations** timed out after 600 and 260 seconds respectively; neither produced a usable result bundle. Both are **NOT TESTED for this Phase 06 automated run**, regardless of successful independent simulator process launches or broad manual approval. Earlier Phase 05 iPhone UI success is historical evidence only.
- `git diff --check` found no whitespace errors. `gsd-sdk query verify.schema-drift 06` reported `drift_detected: false`. Codebase drift reported a non-blocking stale-map warning (`last_mapped_commit: null`) listing historical project files, not a Phase 06 source change.

## Human Verification and Open Coverage

The user approved the requested full manual checklist across the three prepared targets on 2026-09-25 without separately itemizing each observation or OS version; device/OS attribution in the matrix comes from `xcrun simctl list devices available`, `sw_vers`, and the prepared launches. Manual PASS rows are attributed to that statement, not inferred from build or process success.

- **NOT TESTED:** actual macOS 26 runtime launch/drag on a physical Apple Silicon Mac or Metal-capable macOS 26 guest. This remains the Phase 1 `01-HUMAN-UAT.md` milestone-closeout item; PLAT-01 is not marked complete by this phase.
- **NOT TESTED (non-blocking):** iOS physical two-finger field cycling and concurrent touch, per `02-HUMAN-UAT.md` and the user's earlier decision.
- **NOT TESTED (automation for this run):** the timed-out iPhone/iPad HUD suites; do not count them as zero-failure successes.

## Verification Metadata

Goal-backward inspection of Phase 06 PLAN/SUMMARY frontmatter, actual README/project/controller settings, fresh no-override builds and available regression suites, independent process launches, and the user-attributed visual checklist. Verification performed inline because the typed `gsd-verifier` agent is unavailable in this runtime. No new application behavior or solver work was in scope.

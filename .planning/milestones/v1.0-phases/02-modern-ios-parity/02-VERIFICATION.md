---
phase: 02-modern-ios-parity
verified: 2026-09-24T21:08:00Z
status: passed
score: 3/3 phase requirements supported within agreed simulator scope
---

# Phase 2 — Modern iOS parity verification

**Goal:** Bring the existing iOS app onto iOS 26 with familiar fluid interaction, while both schemes build on current Xcode and Mac input remains available.

## Goal achievement

| Criterion | Result | Evidence |
|-----------|--------|----------|
| iOS 26 app launches on iPhone and iPad | PASS (simulator scope) | Xcode 27 no-override Debug build, `MinimumOSVersion=26.0`, `default.metallib`, fresh `simctl install`/`launch` on iOS 26.4 iPhone 17 Pro and iPad Pro 11-inch M5; user opened both in Xcode. See `02-PARITY.md`. |
| iOS fluid responds with familiar default and input | PASS for observed gestures | User reported unobstructed dark-blue density on black, prompt drag, swirl/fade, single tap dye and one-finger double-tap pause/resume on both simulators. Shader RGB/fade/curl and 40 pressure iterations remain unchanged. Two-finger shortcut and physical multi-touch are separately pending in `02-HUMAN-UAT.md`. |
| Both schemes build without Swift 4 or deployment overrides | PASS | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build` and `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` exited 0 after final source changes. Effective iOS Swift 5/iOS 26 and Mac Swift 5/macOS 26 settings were checked. |
| Mac mouse/Space/S parity | PASS via prior macOS 27 observation + fresh build | `01-BASELINE.md` records user-observed mouse, Space and S on macOS 27. No macOS 26 runtime pass claimed; Phase 1 UAT remains pending at milestone closeout. |

## Requirements traceability

Each of `02-01-PLAN.md`, `02-02-PLAN.md`, and `02-03-PLAN.md` declares `PLAT-02`, `PLAT-03`, and `SIM-01`; each has a committed matching SUMMARY with those IDs. `REQUIREMENTS.md` assigns all three to Phase 2. PLAT-02 is verified on two iOS 26 simulators under the user-approved D-09 simulator sign-off; physical-device support is not asserted. PLAT-03 is verified by both scheme builds. SIM-01 is verified for observed Mac and iOS drags, with concurrent-finger behavior pending.

## Artifact and contract checks

- Full-canvas `MTKView` still installs the shared renderer. Swift and Metal compile into both targets, and the bundled iOS metallib exists.
- `StaticData` offsets measured using Swift `MemoryLayout`: positions 0, impulses 80, scalar 160, offsets 168, screen 176, radius 184, stride 192. The matching Metal `float2[10]` arrays and fields have these offsets.
- Contact slots are bounded to ten per force pass, with additional passes for overflow. Empty snapshots zero positions, impulses and scalar; no controller `malloc`/`memcpy`/`memset` remains.
- The iOS Xcode scheme has no configured test action: `xcodebuild ... test` reports “not currently configured for the test action”; no test target exists. Verification used both builds, simulator launches, user observations, and code inspection instead.

## Pending human observations

The user explicitly chose to close Phase 2 with the untried cases pending. `02-HUMAN-UAT.md` retains the two-finger shortcut, independent multi-touch/lift/cancel, and proportional-stroke comparison. Actual macOS 26 runtime belongs to the previously deferred Phase 1 milestone-closeout UAT. None of these pending checks is recorded as passed.

## Gate summary

- Post-execution builds: PASS for both schemes. Automated test suite: NOT AVAILABLE (no test action/target), not a passing test claim.
- Code review: `02-REVIEW.md` status clean at standard depth, no confirmed code defect.
- Prior Phase 1 has no test target; the existing macOS 27 baseline remains the interaction reference and its actual macOS 26 runtime gap stays open.
- Schema drift: none. Codebase drift query emitted a non-blocking map-refresh warning for legacy/unmapped file paths.

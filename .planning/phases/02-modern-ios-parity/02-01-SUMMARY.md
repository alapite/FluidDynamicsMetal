---
phase: 02-modern-ios-parity
plan: 01
subsystem: ios-build
tags: [xcode, ios26, metal, swift5]
requires:
  - phase: 01-modern-mac-baseline
    provides: macOS 26 build configuration and interaction baseline
provides:
  - iOS 26 / Swift 5 build and simulator launch
  - Both-scheme no-override Debug build parity
affects: [02-02, 02-03]
tech-stack:
  added: []
  patterns: [Both schemes compile the shared Metal renderer without deployment overrides]
key-files:
  created: []
  modified: [FluidDynamicsMetal.xcodeproj/project.pbxproj, FluidDynamicsMetaliOS/Info.plist, FluidDynamicsMetaliOS/AppDelegate.swift, FluidDynamicsMetaliOS/RenderViewController.swift]
key-decisions:
  - "Keep the existing full-canvas storyboard and simulation constants."
patterns-established:
  - "Check the built simulator app's OS minimum and Metal library before installation."
requirements-completed: [PLAT-02, PLAT-03, SIM-01]
duration: 3 min
completed: 2026-09-24
---

# Phase 02 Plan 01: iOS build parity summary

**The iOS 26 Swift 5 app builds, installs and launches on an iPhone 17 Pro simulator; the Mac scheme still builds without overrides.**

## Performance
- Started: 2026-09-24T20:47:20Z
- Completed: 2026-09-24T20:50:00Z
- Tasks: 2/2
- Files modified: 4

## Task Commits
- Task 1: `c5a853b` — iOS build settings, Metal device requirement, and required UIKit symbol migrations.
- Task 2: no source changes; both-scheme build and settings verification below.

## Build and launch evidence
- iOS: `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build` — exit 0 after fixing three obsolete UIKit symbols. The original pre-fix attempt failed on those symbols.
- Mac: `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` — `BUILD SUCCEEDED`, exit 0.
- Effective settings (`xcodebuild ... -showBuildSettings -json`): iOS `IPHONEOS_DEPLOYMENT_TARGET=26.0`, `SWIFT_VERSION=5.0`, `TARGETED_DEVICE_FAMILY=1,2`; Mac `MACOSX_DEPLOYMENT_TARGET=26.0`, `SWIFT_VERSION=5.0`. Project and iOS target Debug/Release settings set 26.0 and Swift 5; legacy Swift 3 inference removed.
- The iOS build product is `/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Build/Products/Debug-iphonesimulator/FluidDynamicsMetaliOS.app` (`TARGET_BUILD_DIR` and `WRAPPER_NAME` from `-showBuildSettings`). `/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' .../Info.plist` returned `26.0`; `test -f .../default.metallib` passed.
- `xcrun simctl boot 8393A81F-69D4-439E-AF8E-ED7665022800`, `xcrun simctl bootstatus 8393A81F-69D4-439E-AF8E-ED7665022800 -b`, `xcrun simctl install 8393A81F-69D4-439E-AF8E-ED7665022800 "$APP"`, and `xcrun simctl launch 8393A81F-69D4-439E-AF8E-ED7665022800 ro.andreisergiupitis.FluidDynamicsMetaliOS` all exited 0; launch reported PID 40266 (iPhone 17 Pro, iOS 26.4). Visual drag was not observed.
- Existing Mac `mouseDown`/`mouseDragged`/`mouseUp`, Space and S paths and the shared shader defaults remain in source; the observed Mac interaction reference is `01-BASELINE.md` on macOS 27. macOS 26 runtime remains untested.

## Deviations from Plan
- [Rule 3 — build blocker] Swift 5 compilation exposed obsolete `UIApplicationLaunchOptionsKey` and notification symbols. Changed only their UIKit spelling in the iOS app delegate and controller; the next iOS build exited 0. Commit: `c5a853b`.

## Issues Encountered
- Swift 5 still emits existing `float2` deprecation warnings; these do not prevent either build and are not a behavioral change.

## Next Phase Readiness
- Plan 02 can expand touch input. Simulator launch is not visual verification.

## Self-Check: PASSED
- Built both schemes and inspected actual iOS bundle; simulator installation and launch returned success. Visual behavior remains for Plan 03.

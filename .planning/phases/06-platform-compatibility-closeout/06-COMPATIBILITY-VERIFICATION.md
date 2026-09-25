# Phase 06 — Platform compatibility verification

**Opened:** 2026-09-25. **Requirement:** VER-02. Record only checks performed for this phase as PASS or FAIL; keep the remaining rows NOT TESTED until evidence exists. Build success, process launch, automated tests, and human visual observation are distinct.

## Environment

| Host / tool | Actual version / device | Evidence |
|-------------|-------------------------|----------|
| Mac host / architecture | NOT TESTED | Pending `sw_vers -productVersion`, `uname -m`. |
| Xcode | NOT TESTED | Pending `xcodebuild -version`. |
| iPhone simulator | NOT TESTED | Select from `xcrun simctl list devices available`. |
| iPad simulator | NOT TESTED | Select from `xcrun simctl list devices available`. |

## Builds, bundle and automated checks

| Check | Command / procedure | Host, OS, Xcode or simulator | Result | Evidence |
|-------|---------------------|------------------------------|--------|----------|
| Mac Debug arm64 build without overrides | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` | Pending | NOT TESTED | Pending command result. |
| Root Mac app build/copy | `./build-macos.sh` | Pending | NOT TESTED | Pending command result and root app path. |
| Mac bundle architecture/minimum OS/Metal library | Inspect root `.app` with `lipo -archs`, `/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion'`, and `test -f Contents/Resources/default.metallib` | Pending | NOT TESTED | Pending bundle inspection. |
| Mac state + HUD UI automated tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` | Pending | NOT TESTED | Pending test count and result bundle. |
| Metal regression | `python3 -m unittest test_phase05_metal.py` after fresh Mac build | Pending | NOT TESTED | Pending command result. |
| iOS Simulator Debug build without overrides | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | Pending | NOT TESTED | Pending command result. |
| iOS built app minimum OS/Metal library | Locate actual `Debug-iphonesimulator/FluidDynamicsMetaliOS.app` build product; inspect `MinimumOSVersion` and `default.metallib` | Pending | NOT TESTED | Pending bundle inspection. |
| iPhone HUD UI automated tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=<chosen-iPhone-id>' CODE_SIGNING_ALLOWED=NO` | Pending | NOT TESTED | Pending device/version, count, result. |
| iPad HUD UI automated tests | Same iOS test command with an available iPad ID | Pending | NOT TESTED | Pending device/version, count, result or timeout. |

## Phase 06 live observations — human checkpoint

Follow the numbered [README checklist](../../../README.md) on each available platform. Record observed results and the observer, date and actual OS; a previous phase's approval is historical evidence, not a Phase 06 PASS.

| Platform | Check / human procedure | Host/OS or simulator | Result | Evidence |
|----------|-------------------------|----------------------|--------|----------|
| Mac | Fresh blue-on-black Density, closed Tuning, Force 50% / Dye 40% / Swirl 20% / Fade 17% | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| Mac | Drag outside HUD deposits/swirl/fade | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| Mac | Pause/Resume; select Density, Pressure, Velocity, Vorticity including while paused; Space/S | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| Mac | Change a tuning slider, observe effect, relaunch for closed Tuning and defaults | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| iPhone | Fresh blue-on-black Density, closed Tuning, four default percentages | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| iPhone | Drag outside HUD deposits/swirl/fade | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| iPhone | Pause/Resume; select four named fields including while paused; one-finger double tap | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| iPhone | Change a tuning slider, observe effect, relaunch for defaults | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| iPad | Fresh blue-on-black Density, closed Tuning, four default percentages | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| iPad | Drag outside HUD deposits/swirl/fade | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| iPad | Pause/Resume; select four named fields including while paused; one-finger double tap | Pending | NOT TESTED | Awaiting Phase 06 user observation. |
| iPad | Change a tuning slider, observe effect, relaunch for defaults | Pending | NOT TESTED | Awaiting Phase 06 user observation. |

## Outstanding OS and device-only coverage

| Check | Procedure | Host/device | Result | Evidence / follow-up |
|-------|-----------|-------------|--------|----------------------|
| macOS 26 runtime launch and drag | Launch and stir on actual Apple Silicon macOS 26 host or Metal-capable guest | macOS 26 host not confirmed | NOT TESTED | Milestone closeout: [01-BASELINE.md](../01-modern-mac-baseline/01-BASELINE.md) and pending [01-HUMAN-UAT.md](../01-modern-mac-baseline/01-HUMAN-UAT.md). A macOS 27 launch/build cannot pass this. |
| Two-finger field cycle and concurrent touches | Observe separately on physical iOS 26 iPhone/iPad | Physical device not available in the recorded baseline | NOT TESTED | Device-only, non-blocking: [02-HUMAN-UAT.md](../02-modern-ios-parity/02-HUMAN-UAT.md). Xcode 27 Device Hub two-finger simulation unavailable. |

Historical context only: [05-TUNING-VERIFICATION.md](../05-live-fluid-tuning/05-TUNING-VERIFICATION.md) contains user-approved Mac/iPhone/iPad observations from Phase 05 on 2026-09-25 and an iPad UI-test timeout. This record requires fresh, separately attributed Phase 06 results; an iPad test timeout must remain NOT TESTED even if installation or launch succeeds.

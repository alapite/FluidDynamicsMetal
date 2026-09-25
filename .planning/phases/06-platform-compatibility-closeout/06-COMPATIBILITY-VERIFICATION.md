# Phase 06 — Platform compatibility verification

**Opened:** 2026-09-25. **Requirement:** VER-02. Record only checks performed for this phase as PASS or FAIL; keep the remaining rows NOT TESTED until evidence exists. Build success, process launch, automated tests, and human visual observation are distinct.

## Environment

| Host / tool | Actual version / device | Evidence |
|-------------|-------------------------|----------|
| Mac host / architecture | Apple Silicon arm64, macOS 27.0 | `uname -m` → `arm64`; `sw_vers -productVersion` → `27.0`. This is not a macOS 26 runtime check. |
| Xcode | 27.0 (27A266a) | `xcodebuild -version`; Xcode macOS and iPhone Simulator SDKs 27.0 in build output. |
| iPhone simulator | iPhone 17 Pro, iOS 26.4, `8393A81F-69D4-439E-AF8E-ED7665022800` (Booted) | `xcrun simctl list devices available`; selected for attempted UI suite. |
| iPad simulator | iPad Pro 13-inch (M5), iOS 26.4, `98C63B09-8AB0-4B26-B9C4-5277D60FCBD5` (Booted) | `xcrun simctl list devices available`; selected for attempted UI suite. |

## Builds, bundle and automated checks

| Check | Command / procedure | Host, OS, Xcode or simulator | Result | Evidence |
|-------|---------------------|------------------------------|--------|----------|
| Mac Debug arm64 build without overrides | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` | arm64 Mac, macOS 27.0, Xcode 27.0 | PASS | Exit 0; `** BUILD SUCCEEDED **` (2026-09-25). |
| Root Mac app build/copy | `./build-macos.sh` | arm64 Mac, macOS 27.0, Xcode 27.0 | PASS | Exit 0; `** BUILD SUCCEEDED **`; `App ready: .../FluidDynamicsMetalOSX.app` in project root. |
| Mac bundle architecture/minimum OS/Metal library | `lipo -archs FluidDynamicsMetalOSX.app/Contents/MacOS/FluidDynamicsMetalOSX`; `/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' FluidDynamicsMetalOSX.app/Contents/Info.plist`; `test -f FluidDynamicsMetalOSX.app/Contents/Resources/default.metallib` | Build from arm64 Mac, macOS 27.0, Xcode 27.0 | PASS | `arm64`; `26.0`; Metal library file exists (test exit 0). Minimum OS is metadata, not a macOS 26 launch. |
| Mac state + HUD UI automated tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` | arm64 Mac, macOS 27.0, Xcode 27.0 | PASS | `** TEST SUCCEEDED **`; 11 state/renderer-contact tests + 5 Mac HUD UI tests, 0 failures; `Test-FluidDynamicsMetalOSX-2026.09.25_22-13-13-+0100.xcresult` under Xcode DerivedData `Logs/Test`. Tested the existing uncommitted Mac controller/UI-test workspace edits (see Phase 05 review WR-01). |
| Metal regression | `python3 -m unittest test_phase05_metal.py` after fresh Mac Debug build | arm64 Mac, macOS 27.0, Xcode 27.0 | PASS | Exit 0; `Ran 1 test ... OK` (production Metal RG16F readback). |
| iOS Simulator Debug build without overrides | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | arm64 Mac, macOS 27.0, Xcode 27.0; generic iOS Simulator destination | PASS | Exit 0; `** BUILD SUCCEEDED **`; build alone does not establish process launch or fluid interaction. |
| iOS built app minimum OS/Metal library | `/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' '/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Build/Products/Debug-iphonesimulator/FluidDynamicsMetaliOS.app/Info.plist'`; `test -f '/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Build/Products/Debug-iphonesimulator/FluidDynamicsMetaliOS.app/default.metallib'` | Build from arm64 Mac, macOS 27.0, Xcode 27.0 | PASS | `MinimumOSVersion = 26.0`; `default.metallib` exists (test exit 0). Actual product path taken from iOS build output. |
| iPhone HUD UI automated tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=8393A81F-69D4-439E-AF8E-ED7665022800' CODE_SIGNING_ALLOWED=NO` | iPhone 17 Pro, iOS 26.4 simulator; macOS 27.0 / Xcode 27.0 | NOT TESTED | Invocation timed out after 600 s; no completed test summary or usable `.xcresult` (missing `Info.plist`). Test counts cannot be claimed. Earlier Phase 05 iPhone 6/6 PASS is historical, not this run. |
| iPad HUD UI automated tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=98C63B09-8AB0-4B26-B9C4-5277D60FCBD5' CODE_SIGNING_ALLOWED=NO` | iPad Pro 13-inch (M5), iOS 26.4 simulator; macOS 27.0 / Xcode 27.0 | NOT TESTED | Invocation timed out after 260 s; no completed test summary or usable `.xcresult` (missing `Info.plist`). Earlier Phase 05 iPad UI timeout remains historical. |

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

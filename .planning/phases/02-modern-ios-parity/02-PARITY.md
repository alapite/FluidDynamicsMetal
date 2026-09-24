# Phase 2 — iOS 26 simulator parity evidence

**Recorded:** 2026-09-24. Host: Apple Silicon Mac, macOS 27.0; Xcode 27.0 (27A266a). Reference: [Phase 1 Mac baseline](../01-modern-mac-baseline/01-BASELINE.md) and [original fluid animation](../../../FluidDynamicsMetal.gif). A successful process launch does not verify visible content or touch response. The user subsequently ran the iOS scheme with Xcode on both simulators and reported the visual results below; no screenshot was captured.

## Reproduction

```bash
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' CODE_SIGNING_ALLOWED=NO -showBuildSettings -json
APP='/Users/abiola/Library/Developer/Xcode/DerivedData/FluidDynamicsMetal-azjwdezmeqzeuibhoxwuigioomfx/Build/Products/Debug-iphonesimulator/FluidDynamicsMetaliOS.app'
/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist"
test -f "$APP/default.metallib"
xcrun simctl boot 8393A81F-69D4-439E-AF8E-ED7665022800
xcrun simctl bootstatus 8393A81F-69D4-439E-AF8E-ED7665022800 -b
xcrun simctl install 8393A81F-69D4-439E-AF8E-ED7665022800 "$APP"
xcrun simctl launch 8393A81F-69D4-439E-AF8E-ED7665022800 ro.andreisergiupitis.FluidDynamicsMetaliOS
xcrun simctl boot 1FB7D6F2-2DCF-43F9-BB1A-7031F4702A21
xcrun simctl bootstatus 1FB7D6F2-2DCF-43F9-BB1A-7031F4702A21 -b
xcrun simctl install 1FB7D6F2-2DCF-43F9-BB1A-7031F4702A21 "$APP"
xcrun simctl launch 1FB7D6F2-2DCF-43F9-BB1A-7031F4702A21 ro.andreisergiupitis.FluidDynamicsMetaliOS
```

`TARGET_BUILD_DIR` and `WRAPPER_NAME` from `-showBuildSettings -json` identify the exact app above. Both no-override Debug builds exited 0 on this host. The built iOS `Info.plist` reports `MinimumOSVersion=26.0` and `default.metallib` exists. Both installations were performed after the final source build, not from an earlier bundle. Devices are iPhone 17 Pro (iOS 26.4, `8393A81F-69D4-439E-AF8E-ED7665022800`) and iPad Pro 11-inch (M5) (iOS 26.4, `1FB7D6F2-2DCF-43F9-BB1A-7031F4702A21`). A repeat launch after the final builds returned PID 44273 on iPhone and PID 44982 on iPad.

## Results

| Check | Result | Evidence / observation |
|-------|--------|------------------------|
| iPhone process launch | PASS | `simctl install` and `simctl launch` exited 0, PID 44273; user also ran the app in Xcode on iPhone 17 Pro iOS 26.4 and observed the canvas. |
| iPad process launch | PASS | `simctl install` and `simctl launch` exited 0, PID 44982; user also ran the app in Xcode on iPad Pro 11-inch (M5) iOS 26.4 and observed the canvas. |
| iPhone unobstructed blue-on-black default | PASS | User observed the blue-on-black unobstructed canvas on iPhone 17 Pro, iOS 26.4, 2026-09-24. |
| iPad unobstructed blue-on-black default | PASS | User observed the blue-on-black unobstructed canvas on iPad Pro 11-inch (M5), iOS 26.4, 2026-09-24. |
| iPhone drag and release | PASS | User observed fluid response after dragging and releasing on iPhone 17 Pro, iOS 26.4, 2026-09-24. |
| iPad drag and release | PASS | User observed fluid response after dragging and releasing on iPad Pro 11-inch (M5), iOS 26.4, 2026-09-24. |
| Blue dye swirl and fade | PASS | User observed blue dye moving, swirling and fading on both iOS 26.4 simulator layouts, 2026-09-24; Phase 1 Mac baseline and original GIF are appearance references. |
| Stationary brief single tap adds dye | PASS | User tried the brief single tap and observed dye on both iOS 26.4 simulator layouts, 2026-09-24. |
| Prompt moving touch stirs | PASS | User observed a prompt drag stirring fluid on both iOS 26.4 simulator layouts, 2026-09-24. |
| One-finger double tap pauses/resumes | PASS | User observed pause/resume on both iOS 26.4 simulator layouts, 2026-09-24. |
| Two-finger double tap cycles density → pressure → velocity → vorticity → density | NOT TESTED | Requires reliable simulator two-finger gesture input. |
| One-finger double tap leaves no dye blot | PASS | User reported the tested one-finger shortcut left no dye blot on both iOS 26.4 simulators, 2026-09-24. |
| Two-finger double tap leaves no dye blot | NOT TESTED | User did not perform the two-finger shortcut. |
| Independent concurrent touches | NOT TESTED — device-only | No convincing simulator multi-touch observation or physical device test was reported. |
| Lift/cancel one touch while another continues | NOT TESTED — device-only | No convincing simulator multi-touch observation or physical device test was reported. |
| iPad/iPhone proportional stroke width | NOT TESTED | No explicit canvas-relative stroke-width comparison was reported. |
| Mac Debug arm64 rebuild | PASS | `xcodebuild ... -scheme FluidDynamicsMetalOSX ... CODE_SIGNING_ALLOWED=NO build` exited 0 on macOS 27 host. |
| Mac mouse / Space / S parity | PASS (prior reference only) | User observed mouse, Space and S on macOS 27 in `01-BASELINE.md`, 2026-09-24; no new Mac runtime observation in this phase. |
| Actual macOS 26 runtime | NOT TESTED | Deferred to milestone closeout; macOS 27 rebuild/reference cannot prove this. |

## Human verification checkpoint

The user confirmed blue-on-black, drag/release, swirl/fade, brief single-tap dye, and one-finger pause/resume on both devices after opening the iOS scheme in Xcode. The two-finger shortcut was not tried; independent simultaneous touches and lift/cancel were not reproduced convincingly and remain `NOT TESTED — device-only`. No explicit stroke-width comparison was reported. macOS 26 runtime remains deferred to milestone closeout.

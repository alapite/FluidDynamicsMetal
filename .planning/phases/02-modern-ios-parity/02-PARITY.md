# Phase 2 — iOS 26 simulator parity evidence

**Recorded:** 2026-09-24. Host: Apple Silicon Mac, macOS 27.0; Xcode 27.0 (27A266a). Reference: [Phase 1 Mac baseline](../01-modern-mac-baseline/01-BASELINE.md) and [original fluid animation](../../../FluidDynamicsMetal.gif). A successful process launch does not verify visible content or touch response.

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
| iPhone process launch | PASS | `simctl install` and `simctl launch` exited 0, PID 44273, iPhone 17 Pro iOS 26.4. Screen contents not inspected. |
| iPad process launch | PASS | `simctl install` and `simctl launch` exited 0, PID 44982, iPad Pro 11-inch (M5) iOS 26.4. Screen contents not inspected. |
| iPhone unobstructed blue-on-black default | NOT TESTED | Requires direct simulator screen observation. |
| iPad unobstructed blue-on-black default | NOT TESTED | Requires direct simulator screen observation. |
| iPhone drag and release | NOT TESTED | Requires stirring observation on iPhone simulator. |
| iPad drag and release | NOT TESTED | Requires stirring observation on iPad simulator. |
| Blue dye swirl and fade | NOT TESTED | Compare to Phase 1 Mac baseline and original GIF. |
| Stationary brief single tap adds dye | NOT TESTED | Requires simulator tap observation. |
| Prompt moving touch stirs | NOT TESTED | Requires simulator drag observation. |
| One-finger double tap pauses/resumes | NOT TESTED | Requires simulator gesture observation. |
| Two-finger double tap cycles density → pressure → velocity → vorticity → density | NOT TESTED | Requires reliable simulator two-finger gesture input. |
| Double-tap shortcuts leave no dye blot | NOT TESTED | Requires simulator visual observation. |
| Independent concurrent touches | NOT TESTED — device-only if simulator cannot demonstrate | No physical device test was run. |
| Lift/cancel one touch while another continues | NOT TESTED — device-only if simulator cannot demonstrate | No physical device test was run. |
| iPad/iPhone proportional stroke width | NOT TESTED | Compare trail widths as a fraction of the short side of each canvas. |
| Mac Debug arm64 rebuild | PASS | `xcodebuild ... -scheme FluidDynamicsMetalOSX ... CODE_SIGNING_ALLOWED=NO build` exited 0 on macOS 27 host. |
| Mac mouse / Space / S parity | PASS (prior reference only) | User observed mouse, Space and S on macOS 27 in `01-BASELINE.md`, 2026-09-24; no new Mac runtime observation in this phase. |
| Actual macOS 26 runtime | NOT TESTED | Deferred to milestone closeout; macOS 27 rebuild/reference cannot prove this. |

## Human verification checkpoint

Open each simulator, confirm the blue fluid canvas, drag/release, single tap, one-finger double tap, and (if reliably possible) two-finger double tap. Update the separate rows above to `PASS` or `FAIL` with device and observed details. Compare the iPad trail width as a canvas fraction with the iPhone. If simulator multi-touch cannot convincingly reproduce independent fingers or cancel, retain `NOT TESTED — device-only`. Then report `approved`, or describe any failure and its device/step.

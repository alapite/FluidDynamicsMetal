---
phase: 04-discoverable-visualization
status: awaiting-human-verification
date: 2026-09-25
requirement: CTRL-01
---

# Phase 4 — HUD verification

Environment: macOS 27.0 (26A428), Apple Silicon arm64; Xcode 27.0 (27A266a). Available iOS 26.4 simulators: iPhone 17 Pro (`8393A81F-69D4-439E-AF8E-ED7665022800`) and iPad Pro 13-inch M5 (`98C63B09-8AB0-4B26-B9C4-5277D60FCBD5`). Both simulators accepted a fresh install and launch of `ro.andreisergiupitis.FluidDynamicsMetaliOS`; the Mac Debug app launched (PID 15626). These launch results are not interaction verification.

## Automated evidence

| Check | Exact command | Result |
|-------|---------------|--------|
| Production state tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` | PASS — 6 tests executed, 0 failures; `testDirectFieldSelectionPreservesPauseAndInactivity` executed |
| Mac Debug build | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` | PASS — BUILD SUCCEEDED |
| iOS Simulator Debug build | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | PASS — BUILD SUCCEEDED |

## Mac live interaction — macOS 27.0 host

| Observation | Status | Evidence / reproduction |
|-------------|--------|-------------------------|
| Four names, one selected; direct out-of-order selection | NOT TESTED | Awaiting human click-and-observe checkpoint. |
| Pause label, frozen immediate field switch and Resume | NOT TESTED | Awaiting human observation. |
| Space/S sync and focused button Space toggles only once | NOT TESTED | Awaiting human keyboard observation. |
| HUD clicks add no dye; drag next to HUD and elsewhere stirs | NOT TESTED | Awaiting human pointer observation. |
| 320×240 minimum, narrow resize, whole labels | NOT TESTED | Awaiting human resize observation. |
| Light/Dark, Increase Contrast, Reduce Transparency | NOT TESTED | Awaiting human appearance observation. |
| Larger text/Bold Text, active field after window activation | NOT TESTED | Awaiting human observation. |

## iPhone live interaction — iOS 26.4 simulator, iPhone 17 Pro

| Observation | Status | Evidence / reproduction |
|-------------|--------|-------------------------|
| Four names, one selected; direct selection and on-screen Pause/Resume | NOT TESTED | Awaiting human interaction observation. |
| Paused field switch changes picture without solver motion | NOT TESTED | Awaiting human observation. |
| One-finger double tap updates HUD; two-finger shortcut | NOT TESTED | Awaiting human gesture observation; physical-device-only results require device. |
| HUD tap/double tap creates no dye; adjacent drag stirs | NOT TESTED | Awaiting human observation. |
| One HUD touch plus one canvas finger | NOT TESTED | Physical-device multitouch may be unavailable in simulator. |
| Portrait/landscape safe area and legible labels | NOT TESTED | Awaiting human rotation observation. |
| Light/Dark, Increase Contrast, Reduce Transparency | NOT TESTED | Awaiting human appearance observation. |
| Large text/Bold Text and foreground return | NOT TESTED | Awaiting human observation. |

## iPad live interaction — iOS 26.4 simulator, iPad Pro 13-inch M5

| Observation | Status | Evidence / reproduction |
|-------------|--------|-------------------------|
| Four names, one selected; direct selection and on-screen Pause/Resume | NOT TESTED | Awaiting human interaction observation. |
| Paused field switch changes picture without solver motion | NOT TESTED | Awaiting human observation. |
| One-/two-finger double-tap shortcut sync | NOT TESTED | Awaiting human gesture observation; physical-device-only results require device. |
| HUD tap/double tap creates no dye; adjacent drag stirs | NOT TESTED | Awaiting human observation. |
| One HUD touch plus one canvas finger | NOT TESTED | Physical-device multitouch may be unavailable in simulator. |
| Portrait/landscape and multitasking-width safe areas | NOT TESTED | Awaiting human resize observation. |
| Light/Dark, Increase Contrast, Reduce Transparency | NOT TESTED | Awaiting human appearance observation. |
| Large text/Bold Text and foreground return | NOT TESTED | Awaiting human observation. |

Prior-phase macOS 26 host and physical-device two-finger checks remain deferred; Phase 3's accepted resample risk AR-03-01 is unchanged. Do not sign off CTRL-01 based on the automated rows alone.

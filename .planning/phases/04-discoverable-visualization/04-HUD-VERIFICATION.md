---
phase: 04-discoverable-visualization
status: verified-with-follow-ups
date: 2026-09-25
requirement: CTRL-01
---

# Phase 4 — HUD verification

Environment: macOS 27.0 (26A428), Apple Silicon arm64; Xcode 27.0 (27A266a). Available iOS 26.4 simulators: iPhone 17 Pro (`8393A81F-69D4-439E-AF8E-ED7665022800`) and iPad Pro 13-inch M5 (`98C63B09-8AB0-4B26-B9C4-5277D60FCBD5`). Both simulators accepted a fresh install and launch of `ro.andreisergiupitis.FluidDynamicsMetaliOS`; the Mac Debug app launched (PID 15626). These launch results are not interaction verification.

Human checkpoint response, 2026-09-25: **“Approved. Each of the Mac, iPhone and iPad apps worked as expected with no issues.”** PASS below means the user approved the requested core control/input flow on the named app, without a per-step observation log. Settings variants and physical multitouch not explicitly reported remain NOT TESTED.

## Automated evidence

| Check | Exact command | Result |
|-------|---------------|--------|
| Production state tests | `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` | PASS — 6 tests executed, 0 failures; `testDirectFieldSelectionPreservesPauseAndInactivity` executed |
| Mac Debug build | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` | PASS — BUILD SUCCEEDED |
| iOS Simulator Debug build | `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | PASS — BUILD SUCCEEDED |

## Mac live interaction — macOS 27.0 host

| Observation | Status | Evidence / reproduction |
|-------------|--------|-------------------------|
| Four names, one selected; direct out-of-order selection | PASS | User approved Mac app as working as expected; no individual step notes. |
| Pause label, frozen immediate field switch and Resume | PASS | User approved Mac core interaction; no individual step notes. |
| Space/S sync and focused button Space toggles only once | PASS | User approved Mac core interaction; no individual step notes. |
| HUD clicks add no dye; drag next to HUD and elsewhere stirs | PASS | User approved Mac core interaction; no individual step notes. |
| 320×240 minimum, narrow resize, whole labels | NOT TESTED | User did not report a specific minimum-window or resize observation. |
| Light/Dark, Increase Contrast, Reduce Transparency | NOT TESTED | Specific appearance-settings observations not reported. |
| Larger text/Bold Text, active field after window activation | NOT TESTED | Specific accessibility/activation observations not reported. |

## iPhone live interaction — iOS 26.4 simulator, iPhone 17 Pro

| Observation | Status | Evidence / reproduction |
|-------------|--------|-------------------------|
| Four names, one selected; direct selection and on-screen Pause/Resume | PASS | User approved iPhone app as working as expected; no individual step notes. |
| Paused field switch changes picture without solver motion | PASS | User approved iPhone core interaction; no individual step notes. |
| One-finger double tap updates HUD | PASS | User approved iPhone core interaction; no individual step notes. |
| Two-finger shortcut on a physical device | NOT TESTED | No physical-device observation reported. |
| HUD tap/double tap creates no dye; adjacent drag stirs | PASS | User approved iPhone core interaction; no individual step notes. |
| One HUD touch plus one canvas finger | NOT TESTED | Physical-device multitouch may be unavailable in simulator. |
| Portrait/landscape safe area and legible labels | NOT TESTED | Specific rotation observation not reported. |
| Light/Dark, Increase Contrast, Reduce Transparency | NOT TESTED | Specific appearance-settings observations not reported. |
| Large text/Bold Text and foreground return | NOT TESTED | Specific accessibility/lifecycle observations not reported. |

## iPad live interaction — iOS 26.4 simulator, iPad Pro 13-inch M5

| Observation | Status | Evidence / reproduction |
|-------------|--------|-------------------------|
| Four names, one selected; direct selection and on-screen Pause/Resume | PASS | User approved iPad app as working as expected; no individual step notes. |
| Paused field switch changes picture without solver motion | PASS | User approved iPad core interaction; no individual step notes. |
| One-finger double-tap shortcut sync | PASS | User approved iPad core interaction; no individual step notes. |
| Two-finger shortcut on a physical device | NOT TESTED | No physical-device observation reported. |
| HUD tap/double tap creates no dye; adjacent drag stirs | PASS | User approved iPad core interaction; no individual step notes. |
| One HUD touch plus one canvas finger | NOT TESTED | Physical-device multitouch may be unavailable in simulator. |
| Portrait/landscape and multitasking-width safe areas | NOT TESTED | Specific rotation/multitasking observation not reported. |
| Light/Dark, Increase Contrast, Reduce Transparency | NOT TESTED | Specific appearance-settings observations not reported. |
| Large text/Bold Text and foreground return | NOT TESTED | Specific accessibility/lifecycle observations not reported. |

Prior-phase macOS 26 host and physical-device two-finger checks remain deferred; Phase 3's accepted resample risk AR-03-01 is unchanged. CTRL-01 core control/input flow was approved by the user; unreported variants above remain explicit follow-ups. Xcode 27 Device Hub's missing Option-key two-finger tap/pan simulation is [reported on Apple Developer Forums](https://developer.apple.com/forums/thread/846533). The user explicitly decided on 2026-09-25 that this tooling limit **must not block later phases or milestone completion**; retain NOT TESTED labels without turning them into a release gate.

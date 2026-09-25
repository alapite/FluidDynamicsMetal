# Phase 05 tuning verification — 2026-09-25

## Environment

- Apple Silicon Mac (arm64), macOS 27.0 (26A428), Xcode 27.0 (27A266a).
- iPhone 17 Pro, iOS 26.4 Simulator (23E244), ID `8393A81F-69D4-439E-AF8E-ED7665022800`.
- iPad Pro 13-inch (M5), iOS 26.4 Simulator, ID `98C63B09-8AB0-4B26-B9C4-5277D60FCBD5`. Automated iPad test runs timed out without a usable result; `simctl launch` returned a PID, which proves launch only.
- Prior Phase 1 macOS 26 runtime check and physical two-finger/concurrent touch remain separate, non-blocking NOT TESTED items per the project decision.

## Automated results

| Layer | Exact command / result | Evidence |
|-------|------------------------|----------|
| Mac state + HUD | `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` — PASS, 13/13 | `Test-FluidDynamicsMetalOSX-2026.09.25_20-32-45-+0100.xcresult`; 8 state, 5 Mac UI tests |
| Production Metal | `python3 -m unittest test_phase05_metal.py` — PASS, 1/1 after fresh Mac Debug build | Mac `default.metallib` RG16F readback in `test_phase05_metal.swift` |
| Mac installable Debug app | `./build-macos.sh` — PASS, root-level `FluidDynamicsMetalOSX.app`; `open -a '<root>/FluidDynamicsMetalOSX.app'` launched a process | Mac app ready for visual inspection |
| iOS Simulator build | `xcodebuild -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` — PASS | No deployment overrides |
| iPhone HUD UI | `xcodebuild test -quiet -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'platform=iOS Simulator,id=8393A81F-69D4-439E-AF8E-ED7665022800' CODE_SIGNING_ALLOWED=NO` — PASS, 6/6 | `Test-FluidDynamicsMetaliOS-2026.09.25_20-30-16-+0100.xcresult`; launch, default labels, retained settings, field/pause, HUD/outside double tap, landscape scrolling |
| iPad HUD UI | Same iOS test command with `id=98C63B09-8AB0-4B26-B9C4-5277D60FCBD5` — NOT TESTED (240-second timeout); focused test also timed out at 180 seconds | No passing test result; simulator app launch itself succeeded (`simctl launch` returned PID 47747) |

**Executed new cases:** `testSliderPositionsPreserveOriginalDefaultsAndBounds`, `testFadeMapsContinuousPositionsAcrossOriginalDetent`, `testTuningDisclosureAndDefaultValuesSurvivePauseAndReopen`, `testTuningRemainsOpenAfterCanvasAndFieldChanges`, `testTuningStartsClosedWithSharedDefaultValues`, `testTuningPersistsThroughFieldPauseAndCanvasGestures`, `testLandscapeKeepsFadeAndPauseReachableInsideHUD`, `testLandscapeClosedHudStillExposesAllFields`, `test_tuning_reaches_real_metal_passes`. The previous field/pause state and HUD regression cases also ran.

**Numeric Metal readback:** force-default 0.99658203, dye-default 0.796875 at the sample pixel (Gaussian splat and Float16 rounding); zero-force velocity 0.0 with dye present; zero-dye density 0.0 with force present. On a nonempty field the retained channel changed from 0.9980469 (original 0.998) to 0.99072266 (0.9905 setting) through the same `advect` pass used for velocity and density. A nonuniform stored vorticity field produced velocity `(0, 0)` at swirl 0 and `(0, -0.19995117)` at swirl 0.4 without a new contact. These values are GPU pass readback, not a claim about a visibly observed animation or a whole-frame solver outcome.

## Live observation matrix — awaiting human checkpoint

No visual outcome has been inferred from a build or simulator launch. Record a concrete observation and host in each row before changing NOT TESTED to PASS/FAIL.

| Behavior | Mac macOS 27 | iPhone 17 Pro iOS 26.4 | iPad Pro M5 iOS 26.4 |
|----------|--------------|------------------------|----------------------|
| Fresh launch: closed Tuning, 50/40/20/17% defaults, familiar blue-on-black fluid | NOT TESTED — native/UI tests cover labels only | NOT TESTED — UI tests cover labels only | NOT TESTED |
| Held stroke: changing Force affects next movement; 0% Force adds dye without new motion | NOT TESTED | NOT TESTED | NOT TESTED |
| 0% Dye stirs without depositing; iOS single tap with nonzero Dye deposits | NOT TESTED | NOT TESTED | NOT TESTED |
| Existing moving fluid: Swirl 0% vs higher, without new input | NOT TESTED | NOT TESTED | NOT TESTED |
| Existing density AND velocity: Fade 0% vs 100%, faster to right | NOT TESTED | NOT TESTED | NOT TESTED |
| Pause: adjusting four labels does not advance visible slab until resume; field switch remains available | NOT TESTED | NOT TESTED | NOT TESTED |
| Disclosure retains values across Hide/Reopen, canvas contact and field selection | NOT TESTED — automated Mac HUD check passed | NOT TESTED — automated iPhone HUD check passed | NOT TESTED |
| Compact HUD: Mac 320×240 or iOS landscape/large text; scroll to Fade and operate controls | NOT TESTED | NOT TESTED — automated landscape scroll check passed | NOT TESTED |
| Outside-HUD input and existing shortcuts; HUD events do not stir or trigger shortcuts | NOT TESTED — keyboard UI regression passed | NOT TESTED — single-finger HUD/outside shortcut UI regression passed | NOT TESTED |
| Device-only two-finger field cycle / concurrent iOS touch | Not applicable | NOT TESTED — physical device required | NOT TESTED — physical device required |

## Human checkpoint

Use the already-built root-level Mac app and booted iPhone/iPad simulators. On each available host, compare the default fluid to `FluidDynamicsMetal.gif` and the Phase 1 baseline, then perform the independent Force/Dye and ongoing Swirl/Fade checks described in `05-03-PLAN.md` Task 2. Resize Mac to 320×240, rotate iPhone/iPad, operate Fade and Pause after scrolling, then stir immediately outside the HUD. Record observed PASS/FAIL/NOT TESTED with a concrete note in the matrix. If the iPad simulator UI remains unresponsive, keep iPad observations NOT TESTED and report the host limitation rather than approving unobserved behavior.

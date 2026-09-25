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

## Live observation matrix — user approved 2026-09-25

The user reported: “Approved. All of checklist items pass on all of the target devices.” The PASS entries below are **user-reported observations of the requested checks** on the available Mac, iPhone simulator and iPad simulator—not conclusions inferred from automated tests, and not independently measured frame data. The approval did not establish physical-device multitouch coverage.

| Behavior | Mac macOS 27 | iPhone 17 Pro iOS 26.4 | iPad Pro M5 iOS 26.4 |
|----------|--------------|------------------------|----------------------|
| Fresh launch: closed Tuning, 50/40/20/17% defaults, familiar blue-on-black fluid | PASS — user approved fresh defaults and familiar appearance on Mac | PASS — user approved fresh defaults and familiar appearance on iPhone | PASS — user approved fresh defaults and familiar appearance on iPad |
| Held stroke: changing Force affects next movement; 0% Force adds dye without new motion | PASS — user approved mid-stroke change and dye-only case | PASS — user approved mid-stroke change and dye-only case | PASS — user approved mid-stroke change and dye-only case |
| 0% Dye stirs without depositing; iOS single tap with nonzero Dye deposits | PASS — user approved no-dye stirring | PASS — user approved no-dye stirring and outside-HUD single-tap dye | PASS — user approved no-dye stirring and outside-HUD single-tap dye |
| Existing moving fluid: Swirl 0% vs higher, without new input | PASS — user approved comparison on already-moving fluid | PASS — user approved comparison on already-moving fluid | PASS — user approved comparison on already-moving fluid |
| Existing density AND velocity: Fade 0% vs 100%, faster to right | PASS — user approved faster rightward fade of both fields | PASS — user approved faster rightward fade of both fields | PASS — user approved faster rightward fade of both fields |
| Pause: adjusting four labels does not advance visible slab until resume; field switch remains available | PASS — user approved frozen display and resume | PASS — user approved frozen display and resume | PASS — user approved frozen display and resume |
| Disclosure retains values across Hide/Reopen, canvas contact and field selection | PASS — user approved sticky values and open state | PASS — user approved sticky values and open state | PASS — user approved sticky values and open state |
| Compact HUD: Mac 320×240 or iOS landscape/large text; scroll to Fade and operate controls | PASS — user approved 320×240 scroll reachability | PASS — user approved landscape/large-text scroll reachability | PASS — user approved landscape/large-text scroll reachability |
| Outside-HUD input and existing shortcuts; HUD events do not stir or trigger shortcuts | PASS — user approved outside input and keyboard/HUD isolation | PASS — user approved outside input and single-finger/HUD isolation | PASS — user approved outside input and single-finger/HUD isolation |
| Device-only two-finger field cycle / concurrent iOS touch | Not applicable | NOT TESTED — physical device required | NOT TESTED — physical device required |

## Human checkpoint outcome

Approved by user on 2026-09-25 for all checklist items on all three available target hosts. The iPad's automated UI-test timeout remains recorded independently above; physical iOS two-finger/concurrent touch and macOS 26 runtime remain NOT TESTED under the existing non-blocking follow-up decision.

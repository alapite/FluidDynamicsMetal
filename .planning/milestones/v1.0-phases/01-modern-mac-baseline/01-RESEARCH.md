# Phase 1: Modern Mac baseline — Research

**Researched:** 2026-09-24
**Requirement:** PLAT-01
**Question:** What must change for a macOS 26 / Apple Silicon user to launch and stir the existing fluid, and how can later phases compare its original behavior?

## Current evidence

- Xcode 27.0 on macOS 27.0 provides the macOS 27 SDK. `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` fails because the Mac target's `MACOSX_DEPLOYMENT_TARGET = 10.13` is below Xcode's supported 12.0–27.0 range. Debug and Release Mac target configurations in `FluidDynamicsMetal.xcodeproj/project.pbxproj` both set 10.13 and `SWIFT_VERSION = 4.0`.
- Repeating the build with `-destination 'platform=macOS,arch=arm64' MACOSX_DEPLOYMENT_TARGET=26.0` gets past deployment-target validation and fails while compiling `Shared/Shaders.metal`: `cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain`. Install the component on the execution machine before diagnosing compiler errors. The build has not yet established whether Swift/Metal source changes are needed.
- The Mac scheme uses `FluidDynamicsMetalOSX/RenderViewController.swift` and the shared renderer. `viewDidLoad` installs `Renderer` as `MTKView.delegate`; `mouseDown` and `mouseDragged` send a position tuple, `mouseUp` clears it; Space toggles `MTKView.isPaused`, S cycles density → pressure → velocity → vorticity. The existing `README.md` and `FluidDynamicsMetal.gif` describe/show the legacy interaction.
- `Renderer.draw(in:)` keeps the 40-pass pressure solve and sends GPU buffers into Metal shader entry points. `Shared/Renderer.swift` `StaticData` must retain the layout of `Shared/Shaders.metal` `BufferData`. Source values defining the look include `ScreenScaleAdjustment = 1.0`, `inkRadius = 150`, impulse scalar `(0.8, 0.0)`, shader advection factor `0.998h`, curl `(0.4, 0.4)`, and scalar visualization RGB `(0.0, 0.06, 0.19)`.
- The storyboard-backed Mac app is already a complete interactive vertical path: launch → `MTKView` → Metal pipeline → mouse event → impulse → rendered density. Preserve this path; no UI rewrite, database, or simulation algorithm changes are required in Phase 1.

## Recommended implementation approach

1. Install/confirm the optional Xcode Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`) as an environment prerequisite, not a tracked project change. Re-run the build with the temporary macOS 26 override to expose real compiler diagnostics before selecting source edits.
2. Change the **Mac target** Debug and Release `MACOSX_DEPLOYMENT_TARGET` to `26.0` and its Swift language mode to a compiler-supported modern value (verify with Xcode 27; prefer Swift 5 mode if it minimizes behavior changes). Keep the iOS target migration and project-wide settings for Phase 2; avoid changing shader defaults or input semantics. Fix only concrete Mac/Shared compiler or runtime blockers uncovered by the build.
3. Run a clean arm64 Mac build without deployment-target overrides, inspect the app bundle's minimum OS and architecture, then launch and manually drag to confirm a visible plume that moves after releasing the mouse. Verify Space/S still work. Capture a reproducible default-look reference (source constants, controls, build/run details, original GIF link, and a screenshot of the **running** app if a GUI session is available) for Phase 2 and later parity checks. Do not claim a runtime/screenshot verification unless performed.

## Validation Architecture

There is no test target in this project; Phase 3 owns automated state tests. For Phase 1 use the Mac scheme's Xcode build as the fast automated gate and a short human Metal/GPU interaction check as the manual gate. On an arm64 Mac with Xcode/Metal Toolchain installed:

- Automated: `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` (no `MACOSX_DEPLOYMENT_TARGET` override). Confirm the built executable reports `arm64`, `MinimumOSVersion`/`LSMinimumSystemVersion` or Mach-O build version reflects 26.0, and the compiled default Metal library is in the bundle.
- Manual: launch the built `.app` in a desktop session; drag across the Metal canvas, release, check density appears and evolves; press Space twice and S four times to check familiar interactions. Capture screenshot plus source-constant baseline and environmental details. A macOS 27 host can validate an app *targeting* 26, but an actual macOS 26 launch requires testing on macOS 26 hardware or VM.
- Sampling: build after the project-setting change and after any compiler fix; manually test once the app builds. If the Metal Toolchain is absent, installation is a blocking prerequisite, not a code failure.

## Planning pitfalls and boundaries

- The Xcode deployment error masks Metal compiler diagnostics; the missing Metal Toolchain masks Swift and runtime diagnostics. Do not prescribe speculative solver rewrites.
- A successful build does not prove drawable acquisition, shader-library creation, mouse drag or fluid motion. Keep a manual verification checkpoint in the execution plan.
- Phase 1 only owns Mac launch/stir and reference capture (PLAT-01). Phase 2 owns iOS and both-target modern Swift compatibility; Phase 3 owns resize/pause robustness and automated state coverage.

## Sources

- Local build attempts on 2026-09-24 (commands and diagnostics above), `xcodebuild -version`, `xcodebuild -showsdks`, and `sw_vers`.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj`, `FluidDynamicsMetalOSX/RenderViewController.swift`, `Shared/Renderer.swift`, `Shared/Shaders.metal`, `Shared/MetalDevice.swift`, `README.md`.
- `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/research/PITFALLS.md`.

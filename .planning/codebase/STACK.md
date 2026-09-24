# Technology Stack

**Analysis Date:** 2026-09-24

## Languages and runtime

- Swift 4 (`SWIFT_VERSION = 4.0` in `FluidDynamicsMetal.xcodeproj/project.pbxproj`) drives both native apps; application and simulation code lives in `FluidDynamicsMetaliOS/`, `FluidDynamicsMetalOSX/`, and `Shared/`.
- Metal Shading Language in `Shared/Shaders.metal` implements vertex and fragment stages for simulation and visualization.
- Native iOS and macOS apps; no server runtime, package manifest, or lockfile is present.

## Frameworks and build

- Xcode project `FluidDynamicsMetal.xcodeproj` defines app schemes `FluidDynamicsMetaliOS` and `FluidDynamicsMetalOSX`; check them with `xcodebuild -list -project FluidDynamicsMetal.xcodeproj`.
- UIKit handles touch and gesture input in `FluidDynamicsMetaliOS/RenderViewController.swift`; AppKit handles mouse and keyboard input in `FluidDynamicsMetalOSX/RenderViewController.swift`.
- MetalKit supplies `MTKView` and `MTKViewDelegate` in both controllers and `Shared/Renderer.swift`; Metal supplies command buffers, pipelines, buffers, and textures through `Shared/MetalDevice.swift`.
- Build inputs are listed explicitly in `FluidDynamicsMetal.xcodeproj/project.pbxproj`; `Shared/*.swift` and `Shared/Shaders.metal` are compiled into both targets, not a separately versioned package.
- No test target or test framework is configured in the Xcode project; the tracked iOS scheme has an empty `Testables` section.

## Configuration and platform requirements

- The Xcode project sets iOS deployment target 10.0 on the app target (10.3 at project level), macOS deployment target 10.13, and Swift 4; see `FluidDynamicsMetal.xcodeproj/project.pbxproj`.
- Debug macOS build: `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`.
- Newer Xcode SDKs can reject macOS 10.13; pass `MACOSX_DEPLOYMENT_TARGET=<supported-version>` as a local build-setting override. The Xcode Metal Toolchain must be installed to compile `Shared/Shaders.metal` (`xcodebuild -downloadComponent MetalToolchain` if absent).
- A Metal-capable Apple device is needed at runtime: `Shared/MetalDevice.swift` force-unwraps `MTLCreateSystemDefaultDevice()` and the default Metal library.
- Simulation scale and ink radius are set in `Shared/Renderer.swift`; shader constants such as advection decay and vorticity confinement are in `Shared/Shaders.metal`.

# Integrations

**Analysis Date:** 2026-09-24

## External services

- No network API, database, authentication provider, webhook, or third-party SDK appears in the project build inputs (`FluidDynamicsMetal.xcodeproj/project.pbxproj`) or the application entrypoints (`FluidDynamicsMetaliOS/AppDelegate.swift`, `FluidDynamicsMetalOSX/AppDelegate.swift`).
- `README.md` links to external fluid-simulation articles for background reading; these are documentation links, not application dependencies.

## Apple platform APIs

- Metal device and shader library: `Shared/MetalDevice.swift` creates the default `MTLDevice`, command queue, and default `MTLLibrary`; `Shared/RenderShader.swift` creates render pipeline states using named functions from `Shared/Shaders.metal`.
- MetalKit view lifecycle: each platform's `RenderViewController.swift` constructs a shared `Renderer` and assigns it as its `MTKView` delegate; `Shared/Renderer.swift` creates command buffers and presents the drawable each frame.
- iOS input: `FluidDynamicsMetaliOS/RenderViewController.swift` maps touches into a five-position `FloatTuple`, uses tap recognizers to pause/switch fields, and observes app-active notifications.
- macOS input: `FluidDynamicsMetalOSX/RenderViewController.swift` maps mouse events to simulation coordinates and uses a local `NSEvent` monitor for pause/switch keys.
- Native storyboard and assets are target-specific: `FluidDynamicsMetaliOS/Base.lproj/Main.storyboard`, `FluidDynamicsMetalOSX/Base.lproj/Main.storyboard`, and each target's `Assets.xcassets`.

## Build-time integration points

- `Shared/Shaders.metal` is compiled into each app target; Swift shader function names in `Shared/Renderer.swift` are runtime lookups via `Shared/MetalDevice.swift`.
- The uniform struct layout crosses the Swift/Metal boundary: `StaticData` in `Shared/Renderer.swift` corresponds to `BufferData` in `Shared/Shaders.metal`.
- There are no checked-in dependency-resolution files or external service configuration files; Xcode's project file is the build source of truth.

# Repository Structure

**Analysis Date:** 2026-09-24

## Build and documentation

- `FluidDynamicsMetal.xcodeproj/project.pbxproj` is the target/source/build-setting manifest; schemes are `FluidDynamicsMetaliOS` and `FluidDynamicsMetalOSX`.
- `README.md` documents platform controls and explains that simulation tuning is code-driven; `AGENTS.md` records build and cross-language editing gotchas.
- `.github/stale.yml` configures issue staleness; it does not define build or test automation.

## Platform app targets

- `FluidDynamicsMetaliOS/AppDelegate.swift` and `FluidDynamicsMetalOSX/AppDelegate.swift` are the platform-specific app delegates.
- `FluidDynamicsMetaliOS/Base.lproj/Main.storyboard` and `FluidDynamicsMetalOSX/Base.lproj/Main.storyboard` supply the views used as `MTKView` by each target's `RenderViewController.swift`.
- `FluidDynamicsMetaliOS/RenderViewController.swift` handles touch/tap/lifecycle events; `FluidDynamicsMetalOSX/RenderViewController.swift` handles mouse/keyboard events.
- `FluidDynamicsMetaliOS/Assets.xcassets` and `FluidDynamicsMetalOSX/Assets.xcassets` contain separate app assets; `FluidDynamicsMetalOSX/Assets.xcassets/ColorMap.textureset` is macOS-specific.
- `FluidDynamicsMetaliOS/Info.plist` and `FluidDynamicsMetalOSX/Info.plist` are separate target metadata files; macOS also has `FluidDynamicsMetalOSX/FluidDynamicsMetalOSX.entitlements`.

## Shared simulation code

- `Shared/Renderer.swift`: `MTKViewDelegate`, render loop, uniform-buffer layout, shader names, field selection, resizing, and GPU pass ordering.
- `Shared/Shaders.metal`: vertex/fragment functions invoked by the renderer; update its `BufferData` together with Swift `StaticData`.
- `Shared/Slab.swift`: allocates and swaps per-field ping/pong textures.
- `Shared/RenderShader.swift`: render-pipeline creation and indexed/fullscreen pass encoding.
- `Shared/MetalDevice.swift`: singleton Metal device, default library, command queue, pipeline cache, texture/buffer creation.
- `Shared/ComputeShader.swift`: compute-pipeline wrapper; the current fluid passes in `Renderer.swift` use render shaders rather than this wrapper.

## Where to make changes

- Input or pause/display controls: the affected platform's `RenderViewController.swift`, plus `README.md` if controls change.
- Simulation order, resolution, display selection, or buffer population: `Shared/Renderer.swift`.
- Fluid equations, visualization colors, or boundary behavior: `Shared/Shaders.metal`; check corresponding shader names and uniform layout in `Shared/Renderer.swift`.
- New source files must be added to the appropriate target source phases in `FluidDynamicsMetal.xcodeproj/project.pbxproj`.

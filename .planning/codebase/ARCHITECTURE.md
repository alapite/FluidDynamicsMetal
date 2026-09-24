# Architecture

**Analysis Date:** 2026-09-24

## Pattern overview

- Two native, storyboard-backed app targets use the same GPU simulation implementation. `FluidDynamicsMetaliOS/` and `FluidDynamicsMetalOSX/` handle platform-specific input; `Shared/` owns rendering, simulation state, and shader entrypoints.
- Shared code is compiled into both targets per `FluidDynamicsMetal.xcodeproj/project.pbxproj`, so it has no independent package/module boundary.

## Layers and responsibilities

- Platform UI: `FluidDynamicsMetaliOS/RenderViewController.swift` and `FluidDynamicsMetalOSX/RenderViewController.swift` obtain their `MTKView` from the storyboard, construct `Renderer`, set it as view delegate, and forward interactions via `updateInteraction(points:in:)`.
- Simulation coordinator: `Shared/Renderer.swift` owns five `Slab` fields (velocity, density, divergence, vorticity, pressure), per-frame uniforms, display selection, and the sequence of GPU passes.
- GPU utilities: `Shared/Slab.swift` allocates ping/pong textures; `Shared/RenderShader.swift` configures render passes and pipeline state; `Shared/MetalDevice.swift` owns the singleton device, command queue, and default shader library.
- GPU programs: `Shared/Shaders.metal` contains fragment functions for advection, forces, divergence, pressure, vorticity, gradient subtraction, and display, plus the shared vertex shader.

## Frame data flow

1. A platform controller forwards touch/mouse positions to `Renderer.updateInteraction` in `Shared/Renderer.swift`.
2. `MTKView` invokes `Renderer.draw(in:)`, which waits on a three-slot semaphore and selects the next uniform buffer.
3. The renderer advects velocity and density, optionally applies interaction forces, computes vorticity and confinement, computes divergence, runs 40 Jacobi pressure passes, and subtracts the pressure gradient.
4. Each pass renders into a slab's `pong` texture and calls `swap()` to make that result the next `ping` input; `Renderer` visualizes one selected field into the current drawable and commits one command buffer.
5. `mtkView(_:drawableSizeWillChange:)` recreates slabs and uniform buffers when the view size changes.

## State and contracts

- Simulation fields are in-memory GPU textures; `Shared/Slab.swift` implements ping/pong state, and `Shared/Renderer.swift` keeps pressure across frames.
- `StaticData` in `Shared/Renderer.swift` must match the memory layout of `BufferData` in `Shared/Shaders.metal` (five positions, five impulses, scalar impulse, offsets, dimensions, radius).
- `RenderShader` receives shader function names as strings in `Shared/Renderer.swift`; those names must exist in `Shared/Shaders.metal`.
- `Shared/MetalDevice.swift` throws for absent named functions, but `Shared/RenderShader.swift` prints pipeline creation errors and leaves pipeline state nil, so a failed pass can silently skip during drawing.

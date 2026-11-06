# Architecture Research

**Milestone:** v1.1 — 3D Teaching Foundation
**Researched:** 2026-11-06
**Confidence:** MEDIUM; recommended integration design, not implemented

## System Overview

Native Mac controls/input → dimension-aware state routing → 2D or 3D simulation encoder → matching visualization → existing MTKView.

Keep the existing 2D solver as the reference path. Add a small 3D implementation with explicit field and camera contracts. Share transport semantics, device access, and verification infrastructure where they already fit; avoid forcing both solvers into a dimension-generic abstraction before the 3D path works.

## Component Responsibilities

Proposed names indicate responsibilities; phase planning may adapt them to local conventions.

| Component | New/modified | Responsibility |
|-----------|--------------|----------------|
| `FluidSimulation3D` in `Sources/Shared/` | New | Own volume resources and encode reset/one logical step without a drawable or wall clock |
| 3D field storage and uniforms | New | Explicit dimensions, scalar/vector formats, ping/pong state, Swift/Metal ABI |
| `ExperimentRecipes3D` | New | Deterministic nonplanar flow/dye seed and initial-speed variants |
| 3D compute shader entry points | New | Advection, compatible divergence/pressure/gradient, boundaries; diagnostic curl only if needed |
| `FieldVisualization3D` | New | Slices and later volume ray marching, consuming simulation fields read-only |
| `ParticleSystem3D` | New | Deterministic passive markers advanced once per simulation step |
| Camera/inspection state | New | Orbit, bounded zoom, reset view, slice axis/depth, overlay visibility |
| `Renderer` and `SimulationState` | Modified | Active-path selection, transport, lifecycle, completion, resource replacement |
| Mac controller/native controls | Modified | 3D selection and camera gestures; controls consume events before canvas routing |
| Existing Xcode project and GPU harness | Modified | Target membership, production-library loading, volume upload/readback, regression checks |

## Numerical Contract: Decide Before Kernel Porting

Define domain coordinates, grid spacing, velocity units, time step, pressure scaling, interpolation locations, and all six boundary faces together. The 2D app currently uses cell-centred central derivatives and a nearest-neighbour Jacobi stencil. Blindly extending these can leave divergence and gradient composition inconsistent with the pressure operator.

Recommendation: evaluate a staggered MAC velocity layout as the correctness-first design for the new solver. A collocated implementation remains possible only with a documented compatible operator choice and verified projection behaviour. Do not require a wholesale 2D rewrite. Establish a small CPU/reference fixture and measure residual plus post-projection divergence before deciding iteration count, pressure precision, or a more advanced solver.

Start with semi-Lagrangian advection and a bounded time step. Vorticity confinement is optional for this advection-only milestone, not a prerequisite: avoid adding an unvalidated visual force to make a weak lesson look lively. If required later, use the genuine 3D curl and cross-product formulation.

## Data Flow

1. Entering 3D drains/retires in-flight resources using the existing synchronization pattern, clears pending input/steps, seeds fields and tracers, and opens paused at step zero.
2. A logical step snapshots deterministic parameters, evolves velocity, projects it, and advances dye/tracers using a documented time level/order. Test the ordering rather than silently depending on the 2D pass order.
3. Read-only presentation consumes the current field state and a separate camera/inspection snapshot. Camera changes, resizing, hidden overlays, and missing drawables never define simulation time.
4. Restart resets every evolution-dependent field/buffer, including pressure guesses and tracer state, while preserving agreed presentation preferences and selected speed.
5. A harness uses the same encoder without a view. Readback and synchronization occur for assertions/timing, not every live frame.

## Integration Constraints

- Both app targets compile shared Swift/Metal. Mac-only UI routing must not accidentally expose an incomplete iOS mode or introduce AppKit imports into shared code.
- New uniforms must use explicitly checked alignment/offsets; `SIMD3` and Metal `float3` have padding rules. Do not grow the old contact ABI casually.
- Window resizing changes presentation resources only; the 64³ simulation grid stays fixed.
- Inactive app lifecycle pauses evolution without catch-up. Leaving 3D clears camera gesture state before 2D pointer injection resumes.
- Initialization failures should identify the failed resource/pipeline and offer a return to the existing experience rather than a blank view.

## Scaling Considerations

64³ is 4× the cell count of 256², 96³ is 13.5×, and 128³ is 32×. Wider fields, more stencil samples, and pressure iterations mean these are not frame-time ratios. Resource estimates must include all ping/pong fields, staging, tracers, and screen-sized rendering targets. Volume rendering scales with pixels × ray samples independently of simulation-grid cost.

## Sources

- Current `Sources/Shared/{Renderer,FluidSimulation,SimulationState,Slab,SimulationTypes,ParticleSystem,FieldVisualization}.swift` and `Shaders.metal`.
- [GPU Gems 3 Chapter 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids), especially §§30.2.3–30.2.4 and 30.3.1. Historical collocated example explicitly notes the robustness of staggered MAC grids.
- [Bridson/Müller-Fischer fluid simulation course index](https://www.cs.ubc.ca/~rbridson/fluidsimulation/): pressure-solve/advection references for deeper phase research. Linked presentation/PDF contents were not reviewed in this milestone research.
- Apple API references in `STACK.md`.

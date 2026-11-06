# Project Research Summary

**Project:** FluidDynamicsMetal
**Milestone:** v1.1 — 3D Teaching Foundation
**Domain:** Interactive educational volumetric fluid simulation on Apple Silicon Mac
**Researched:** 2026-11-06
**Confidence:** MEDIUM overall; hardware performance and numerical tolerances remain unmeasured
**Execution:** Research, synthesis, and review performed inline; no independent-agent verification claimed.

## Executive Summary

Deliver a separate compute-based 64³ fluid path inside the existing Metal app, with one genuinely nonplanar dye-advection lesson. The established Swift/Metal/MetalKit stack is sufficient; no external library or scene framework is recommended. Existing transport conventions and the production GPU harness are useful integration points, while the 2D shader/storage implementation should remain a reference rather than becoming a dimension-generic rewrite.

The largest correctness risk is pressure projection: appending a z component to the existing 2D stencils and preserving 40 Jacobi iterations does not establish a consistent or sufficiently converged 3D solve. Define the operator, boundary, precision, and time-step contract first, evaluate staggered MAC storage, and verify pressure residual and post-projection divergence. The initial lesson also needs measurable nonplanar motion and an early comparison window where increased initial speed has an intelligible effect despite circulation and numerical diffusion.

Build a visible slice-based vertical slice first, add camera/slice/tracer inspection next, complete the comparative teaching flow, and finish with basic volume rendering and a measured quality budget. A volume image is useful context but can conceal interior motion; slices and markers are core teaching tools. Performance must be measured separately for solver and rendering at a stated output size. Historical 2D timing and old GPU Gems hardware figures are not 3D performance forecasts.

## Key Findings

### Recommended Stack

See [STACK.md](STACK.md). Retain Swift 6 language mode, Swift 6.2+/Xcode 26+ tooling, macOS 26 Apple Silicon deployment, MetalKit, the existing command-buffer API, native Mac controls, and XCTest/Swift GPU harnesses. Add 3D textures, compute pipelines, separate uniforms, camera matrices, and a ray-marching display path. Read GPU timings after command completion.

### Expected Features

See [FEATURES.md](FEATURES.md). Approved scope is one 64³ Mac dye-advection lesson, deterministic transport, orbit camera, movable slices, passive tracers, basic volume rendering, and numerical/performance validation. Detailed requirements should confirm dye-only inspection, 600-step lesson semantics, and a benchmark target. Other 3D lessons, mobile 3D, freehand injection, advanced field overlays/trails, and user-selectable high-resolution presets remain future work unless explicitly added.

### Architecture Approach

See [ARCHITECTURE.md](ARCHITECTURE.md). Add separate 3D evolution, recipe, field-storage, visualization, and marker components; extend existing renderer/state/Mac controller routing. Keep evolution callable without a drawable and keep camera/inspection state read-only with respect to fluid evolution. Validate the Swift/Metal ABI and ensure shared additions still compile into both app targets.

### Critical Pitfalls

See [PITFALLS.md](PITFALLS.md).

1. Inconsistent projection operators or inadequate pressure convergence: establish numerical fixtures first.
2. A planar extrusion disguised as 3D: verify depth-varying, out-of-plane trajectories.
3. Camera/display state changing experiment results: compare full state at equal step counts under varied presentation schedules.
4. Numerical diffusion or circulation invalidating the speed lesson: validate visible dye and a predetermined comparison window.
5. Opaque or expensive volume rendering: retain slice/tracer inspection, use bounded sampling, and measure output-size-dependent cost.

## Implications for Roadmap

Suggested delivery boundaries, subject to approved requirements:

### Phase 7: First 3D Fluid Vertical Slice

**Delivers:** Selectable Mac 3D mode with an evolving deterministic seed visible through a fixed slice, basic transport, and numerical evidence.
**Rationale:** Proves integration and actual dynamics before richer rendering. Addresses projection, boundary, ABI, and 2D regression risks immediately.

### Phase 8: Spatial Inspection

**Delivers:** Orbit/zoom/reset camera, orthogonal movable slices, passive markers, and presentation-independent evolution.
**Rationale:** Users need a way to understand depth before the lesson comparison and transparency can be judged.

### Phase 9: Repeatable 3D Advection Lesson

**Delivers:** Speed choices, reproducible restart, 600-step completion, educational explanation, and evidence of the intended comparison.
**Rationale:** Numerical motion alone is not a completed teaching experience; the comparison must be intelligible and repeatable.

### Phase 10: Volume View and Measured Release Quality

**Delivers:** Basic transparent dye volume with view controls, compositing checks, and measured end-to-end performance and compatibility evidence.
**Rationale:** Add the most expensive display path after numerical and educational correctness are established. Validate features throughout earlier phases; this phase closes the integrated experience rather than postponing all tests.

### Research Flags

- **Phase 7:** Deeper numerical research required for compatible operators, boundary conditions, velocity storage, precision, and pressure convergence; verify formats with Metal validation.
- **Phase 8:** Inspect existing native UI/input patterns and coordinate conventions; camera/slice math has standard patterns, but volume/marker alignment needs fixtures.
- **Phase 9:** Experiment design requires measurement of nonplanar trajectories and speed ordering, not a general framework survey.
- **Phase 10:** Research ray-step opacity, marker compositing, rendering budget, and representative drawable sizes; benchmark on the actual release reference Mac.

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Stack | MEDIUM | Current Apple docs and Context7 align with existing source; new path not compiled |
| Features | MEDIUM | User-approved scope plus existing product conventions; detailed requirements pending |
| Architecture | MEDIUM | Source-grounded integration proposal; numerical layout remains a planning decision |
| Pitfalls | MEDIUM | Code inspection, official API guidance, historical fluid reference; validate mitigations in implementation |
| Frame rate / precision / iterations | LOW | No 3D benchmark or numerical fixture exists yet |

### Gaps to Address

- Requirements follow-up confirmed a 30 fps floor at 64³ / 1280×720 on a named available Apple Silicon reference Mac, with 60 fps an optimization goal; select and record the actual benchmark host during implementation.
- In Phase 7, define reference fixtures and tolerances before implementation acceptance; establish projection quality independently of image appearance.
- Choose a nonplanar initial flow with compatible boundaries and calibrate the educational observation window.
- In volume planning, define output-size/ray-step budgets and the tracer/volume visibility contract.
- Actual macOS 26 and physical mobile runtime checks remain historical coverage gaps; current host results cannot silently close them.

## Inline Review

Reviewed the four research artifacts against the approved scope and current source. Recommendations do not mandate extra lessons, mobile 3D, obstacles, a scene engine, or a 2D rewrite. Numerical and performance claims are explicitly proposals or validation tasks, not results. The important refinement from review is to require a compatible discrete projection, not merely a six-neighbour port, and to test nonplanar motion rather than infer it from the camera. Prior modernization research is preserved in `.planning/milestones/v1.0-research/`.

## Sources

- Context7 `/websites/developer_apple_metal`, queried 2026-11-06 for textures/storage, compute sizing, and timing (GSD provider classification MEDIUM).
- [Apple: 3D textures](https://developer.apple.com/documentation/metal/mtltexturetype/type3d.md).
- [Apple: threadgroup and grid sizing](https://developer.apple.com/documentation/metal/calculating-threadgroup-and-grid-sizes.md).
- [GPU Gems 3 Chapter 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids), 2007, historical algorithm/rendering reference. GSD webfetch provider classification LOW; not a current Metal benchmark.
- [Bridson/Müller-Fischer course index](https://www.cs.ubc.ca/~rbridson/fluidsimulation/), for further pressure/advection research; linked PDF/presentation contents not reviewed.
- Current `Sources/Shared/` code, `AGENTS.md`, `README.md`, and `docs/educational-release-verification.md`.

---
*Research completed: 2026-11-06. Ready for requirements and roadmap scoping.*

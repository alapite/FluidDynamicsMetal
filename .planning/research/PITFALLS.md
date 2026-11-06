# Pitfalls Research

**Milestone:** v1.1 — 3D Teaching Foundation
**Researched:** 2026-11-06
**Confidence:** MEDIUM for source-grounded risks; exact thresholds/performance remain unmeasured

## Critical Pitfalls

### 1. Attractive motion without a valid projection

**Failure:** A six-neighbour Jacobi port runs but leaves substantial divergence, especially at boundaries or grid-scale modes.
**Cause:** Reusing 40 iterations, half-precision pressure, or incompatible divergence/gradient/Laplacian operators without numerical checks.
**Prevention:** Define the discrete operator/boundary contract first. Validate known fields and compare pressure residual, pre/post-projection divergence, and wall-normal velocity. Prefer compatible staggered operators unless an alternative is justified. Lock acceptance tolerances before accepting results; increasing iterations cannot repair inconsistent operators.
**Early signals:** Residual decreases while divergence does not; checkerboard pressure; leakage near one face.
**Address in:** First 3D vertical slice and its phase-specific numerical research.

### 2. A planar lesson disguised as 3D

**Failure:** The camera orbits a volume but motion is confined to parallel planes.
**Prevention:** Seed a boundary-compatible nonplanar flow and place dye/tracers where they traverse depth. Test out-of-plane displacement and variation through depth; nonzero z velocity alone does not prove rich three-axis dynamics.
**Early signals:** Every slice shows the same flow; all tracer trajectories remain in a plane.
**Address in:** Initial seed design, then speed-comparison lesson validation.

### 3. Camera actions alter the experiment

**Failure:** Paused orbiting advances fluid, hidden tracers stop evolving, resize changes resolution, or entering/leaving 3D injects a stale force into 2D.
**Prevention:** Separate presentation state from evolution; advance markers only with logical steps; compare complete state after equal step counts under different camera/display schedules; clear input on mode changes.
**Address in:** Slice/tracer inspection and state integration.

### 4. The dye disappears before the teaching observation

**Failure:** Coarse-grid numerical diffusion or excessive fading removes the dye signal; a faster swirling blob returns near its start so final centroid displacement reverses the expected ordering.
**Prevention:** Choose a well-resolved blob and controlled speed range. Validate speed ordering at a preregistered early observation window or use a justified path-length measure. Keep explicit decay separate from numerical dissipation. If the first-order method fails, investigate limited higher-order advection before increasing resolution.
**Address in:** Lesson design and deterministic capture checks.

### 5. Transparency hides rather than explains

**Failure:** A saturated volume conceals interior motion; camera angle or ray-step count changes apparent dye concentration; markers always draw in front with misleading depth.
**Prevention:** Keep a slice-first default and explicit view visibility choices. Use bounded ray-box intersection, front-to-back accumulation, sample-distance-aware opacity, and a documented tracer compositing policy. Test empty/constant/asymmetric volumes and rotated camera views. Do not imply volumetric brightness equals point concentration.
**Address in:** Inspection UI and volume-rendering delivery.

## Performance and Integration Traps

| Trap | Warning sign | Prevention |
|------|--------------|------------|
| Treating 64³ as a guaranteed 60 fps target | Solver fits budget but Retina ray marching stalls | Measure solver, slices/tracers, and volume separately at stated output dimensions |
| CPU waits/readback in the live loop | UI stalls despite moderate GPU time | Keep readback in harness; use completion-based timing and bounded in-flight work |
| Resources recreated on orbit/resize | Allocations and pauses during inspection | Reuse simulation fields, resize only presentation targets |
| Only Mac target checked after shared-code edits | iOS build or old lesson tests fail | Both scheme builds and existing 2D regressions remain acceptance checks |
| SIMD/Metal ABI mismatch | One velocity component or depth coordinate is corrupt | Explicit layout checks and asymmetric 3D fixtures |
| Restart resets dye but retains solver/tracer history | Repeated runs diverge | Reset all evolution-dependent state; compare full fields and markers |
| Mistaking stable advection for accurate transport | No NaNs but smeared teaching signal | Quantify displacement, spread, mass drift and visible lesson outcomes |

## Looks-Done-But-Isn't Checklist

- [ ] All three axes and six faces have asymmetric numerical fixtures.
- [ ] Projection reduces divergence and satisfies the chosen boundary contract.
- [ ] Lesson demonstrates out-of-plane motion and the intended speed comparison.
- [ ] Restart and presentation-independence tests use the production encoder.
- [ ] Camera/slice controls work while paused and never inject fluid.
- [ ] Volume view handles empty and nonuniform fields without hiding all markers.
- [ ] Timings state hardware, OS, build configuration, grid, output dimensions, warm-up, sample count, and statistic.
- [ ] Legacy 2D Mac/iOS build and regression evidence is recorded; unavailable hardware coverage stays explicit.

## Sources

- Current app source and `docs/educational-release-verification.md`.
- [GPU Gems 3 Chapter 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids), 2007: boundary-aware projection, advection diffusion, precision/bandwidth, ray-march filtering/compositing. GSD webfetch provider classification LOW; treat as historical guidance requiring implementation checks, not measured Metal behaviour.
- Apple threadgroup and timing documentation through Context7 (MEDIUM) and direct official threadgroup documentation; links in `STACK.md`.

# Feature Research

**Milestone:** v1.1 — 3D Teaching Foundation
**Researched:** 2026-11-06
**Confidence:** MEDIUM for proposed teaching design; approved scope is direct user input

## Feature Landscape

This is a focused teaching extension, not a commercial feature survey. Expectations below derive from the existing educational app and the user-approved milestone.

### Table Stakes

| Feature | Why needed | Complexity | Dependency |
|---------|------------|------------|------------|
| True three-axis evolving velocity and dye at 64³ | Establish that this is a fluid volume, not an extrusion or animated camera | HIGH | Validated projection, boundaries, advection |
| Mac mode entry and reliable return to 2D | Integrate into the existing app | MEDIUM | Renderer/state routing and resource lifecycle |
| Deterministic lesson transport | Let learners inspect and compare equal step counts | MEDIUM | Fixed step semantics, reset ownership |
| Slow/normal/fast initial-speed comparison | Preserve the current advection lesson's question | MEDIUM | Nonplanar divergence-controlled seed and observable measurement window |
| Movable orthogonal dye cross-section | Expose interior concentration without occlusion | MEDIUM | Volume sampling and shared world coordinates |
| Orbit/zoom/reset camera with orientation cues | Make 3D space understandable | MEDIUM | Projection matrices and native input routing |
| Passive 3D tracers | Reveal motion through depth | MEDIUM | Consistent velocity interpolation and boundary handling |
| Basic transparent dye volume | Show overall dye shape | HIGH | Ray-box intersection, sampling, compositing, performance budget |

### Teaching Differentiators

- Camera, slice, and visibility changes can be made while paused without changing simulated state.
- A concise explanation distinguishes dye concentration from an actual water surface and numerical smoothing from physical diffusion.
- Reproducible restarts allow equal-step comparisons on the same device and implementation.
- Evidence records actual out-of-plane motion and numerical quality, rather than using an attractive image as proof.

### Deferred Features and Anti-Features

| Feature | Disposition | Reason |
|---------|-------------|--------|
| 3D interacting vortices and stirring | Future | User selected the one-lesson foundation |
| iPad/iPhone 3D UI | Future | Real-device performance/input design follows the Mac baseline |
| Freehand 3D injection | Future | Depth selection and gesture arbitration are a separate interaction problem |
| 3D pressure/velocity/vorticity display suite and arrows | Future unless explicitly selected | User approved dye inspection and tracers; scalar signed 2D curl semantics do not carry over |
| Tracer trails and streamlines | Future unless explicitly selected | Passive markers suffice for the first scope; trails add clutter and compositing cost |
| Arbitrary oblique slices, multiple synchronized viewports | Future | Orthogonal axis/depth selection offers a bounded first inspection tool |
| Free-surface water, fire, buoyancy, obstacles | Out of scope | Different physics and visualization requirements |
| Calibrated physical time or cross-device bitwise replay | Out of scope | Existing teaching contract is qualitative and step-based |
| User-selectable 128³/256³ quality presets | Future | Benchmark higher resolutions after validating 64³ |

## Feature Dependencies and Build Order

1. Deliver a selectable 3D lesson seed evolving under production kernels, visible through a basic fixed slice, with pause/step/reset and numerical checks.
2. Add orbit camera, movable slices, and passive tracers; validate that presentation changes cannot alter evolution.
3. Finish the speed-comparison teaching contract, reproducible 600-step lesson, and readable native controls/help.
4. Add basic volume rendering with clear visibility controls and a measured release-quality budget.

This ordering is a recommendation for requirements-based roadmapping, not an approved roadmap. Numerical and regression tests belong with each feature, not solely in a final test phase.

## Decisions Still Needed for Requirements

- Confirm that dye-only slices and passive tracers are sufficient; other field views and trails remain future scope.
- Confirm a performance target and reference hardware policy; no 3D benchmark exists yet.
- Confirm familiar 600-step completion, current-speed restart, and reset-on-adjustment semantics.

## Sources

- User-approved v1.1 scope, 2026-11-06.
- `README.md`, `docs/first-educational-release-plan.md`, and `docs/educational-release-verification.md` for existing teaching conventions.
- [GPU Gems 3, Chapter 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids), 2007, for volumetric representation and visualization considerations. Historical technical reference, not user research or modern hardware evidence.

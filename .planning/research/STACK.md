# Stack Research

**Milestone:** v1.1 — 3D Teaching Foundation
**Researched:** 2026-11-06
**Confidence:** MEDIUM; APIs checked, implementation performance unmeasured
**Method:** Inline research using Context7, primary documentation, and current source inspection.

## Recommended Stack

| Technology | Version/baseline | Purpose | Rationale |
|------------|------------------|---------|-----------|
| Swift + simd | Swift 6 language mode; Swift 6.2+ | State, deterministic seeds, camera matrices, GPU orchestration | Existing app baseline; no new language/runtime |
| Metal + MetalKit | macOS 26 deployment baseline; Xcode 26+ SDK/toolchain | Compute-based 3D evolution and MTKView presentation | Existing command queue/device infrastructure; volume textures and compute dispatch are established APIs |
| Existing native Mac UI | AppKit/controller integration, existing controls | Mode selection, lesson transport, inspection controls | Extend current app patterns rather than introducing a scene engine |
| XCTest + existing integration harness | Project targets; Swift GPU harness driven by Python | Numerical fixtures, state/interaction checks, production-encoder timing | Existing harness already separates GPU evolution from a drawable |

### Supporting libraries and installation

No third-party dependency or package installation is recommended. Both app targets compile `Sources/Shared/` directly. Retain the current Xcode project, platform minimums, Swift mode, and installed Metal Toolchain. Framework APIs ship with the SDK, not independently versioned packages.

## GPU Representation

- Introduce separate 3D field resources using `.type3D`, explicit width/height/depth, and `.shaderRead`/`.shaderWrite` usage where needed. Retain ping/pong ownership for dependent updates.
- Use GPU-private storage for persistent simulation fields; use GPU initialization or staging/blits for seeds and test readback. Persistent fields cannot use memoryless storage.
- Scalar dye and pressure deserve scalar storage. Three-component velocity can use padded vector storage or separate face-centred components depending on the discretization selected in phase planning.
- Prefer a correctness-first pressure precision baseline (float32), then measure whether lower precision is acceptable. Do not impose the old RG16F format on all fields.
- Size 3D threadgroups using each pipeline's execution width and maximum total thread count. Benchmark choices rather than assuming the largest group is fastest.
- Retain the established command-buffer API; a Metal 4 migration is not required for this scope.

## Alternatives Considered

| Recommended | Alternative | Trade-off |
|-------------|-------------|-----------|
| Dense 64³ grid | Sparse volumes | Dense grids are simpler to validate; sparse allocation is premature for this baseline |
| Compute-based 3D updates | Render every volume slice | Compute expresses a 3D dispatch directly and avoids extending the current full-screen-pass abstraction across slices |
| Direct Metal visualization | SceneKit/RealityKit integration | A scene framework may help a future scene-heavy app; it introduces unnecessary ownership/compositing boundaries for one educational volume |
| Basic semi-Lagrangian advection initially | Limited MacCormack/BFECC | Higher-order advection may retain detail better, but adds passes and limiter validation; consider only if the 64³ lesson loses its teaching signal |
| Measured pressure solve | Automatically retain 40 Jacobi iterations | Existing iteration count is a 2D implementation choice, not evidence of 3D convergence |

## Verification and Performance Tools

Use production kernels in the offscreen harness, Metal validation/GPU capture during development, and completed-command-buffer `gpuStartTime`/`gpuEndTime`. Report wall-clock pacing separately from GPU execution time. Measure simulation-only, slices/tracers, and volume rendering independently. Exact resource formats, iteration counts, and display-size budget remain phase-planning decisions.

## Sources

- Context7 `/websites/developer_apple_metal`: texture descriptors/storage, compute dispatch sizing, completed-command-buffer GPU timing. GSD provider classification: MEDIUM.
- [Apple: type3D](https://developer.apple.com/documentation/metal/mtltexturetype/type3d.md), retrieved 2026-11-06.
- [Apple: threadgroup/grid sizing](https://developer.apple.com/documentation/metal/calculating-threadgroup-and-grid-sizes.md), retrieved 2026-11-06; cross-checks Context7.
- [Apple: command-buffer completion](https://developer.apple.com/documentation/metal/mtlcommandbuffer/addcompletedhandler(_:)), via Context7.
- `Sources/Shared/{FluidSimulation,Renderer,Slab,FieldVisualization,ParticleSystem}.swift`, `AGENTS.md`, and `docs/educational-release-verification.md`.

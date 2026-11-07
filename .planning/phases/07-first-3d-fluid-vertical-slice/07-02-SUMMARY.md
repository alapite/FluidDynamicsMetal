---
phase: 07-first-3d-fluid-vertical-slice
plan: 02
subsystem: simulation
tags: [swift, metal, 3d-textures, mac-grid, advection, gpu-fixtures]

# Dependency graph
requires: [07-01]
provides:
  - Checked Float32 private 3D cell/MAC volume storage and staging
  - A separately aligned 48-byte Swift/Metal 3D uniform ABI
  - Production RK2/trilinear velocity and dye advection with reflected boundaries
  - Production-metallib storage, ABI, advection, and wall acceptance fixtures
affects: [07-03, 07-04, 07-06]

# Tech tracking
tech-stack:
  added: [Metal type3D r32Float fields, independent 3D compute kernels]
  patterns: [checked resource construction, aligned staging, old-generation transport, CPU-oracle GPU comparisons]

key-files:
  created:
    - .planning/phases/07-first-3d-fluid-vertical-slice/07-02-SUMMARY.md
    - Sources/Shared/SimulationTypes3D.swift
    - Sources/Shared/VolumeField3D.swift
    - Sources/Shared/FluidSimulation3D.swift
    - Sources/Shared/Shaders3D.metal
    - Tests/Integration/test_fluid3d.py
    - Tests/Integration/test_fluid3d.swift
  modified:
    - FluidDynamicsMetal.xcodeproj/project.pbxproj
    - Tests/Integration/fluid3d_reference.swift
    - Tests/Integration/test_fluid3d_reference.py
    - .planning/STATE.md
    - .planning/ROADMAP.md

key-decisions:
  - "Keep the 3D ABI independent from the existing 2D StaticData/BufferData ABI."
  - "Use reflected physical-domain coordinates and per-axis parity; clamp only the RK2 midpoint/departure positions."
  - "Reject spacing whose reciprocal or configured domain extents are nonfinite before dispatch."
  - "Keep 3D advection unconnected to the user-facing renderer until compatible projection is delivered in 07-03."

requirements-completed: []

# Metrics
duration: 60min
completed: 2026-11-07
---

# Phase 7 Plan 07-02 Summary

**Production 3D volume storage, the Swift/Metal ABI, and three-axis staggered advection now pass actual-Metal GPU comparisons against the independent Double oracle.**

## Performance

- **Duration:** Approximately 60 minutes for this execution window.
- **Started:** 2026-11-07T07:47:14Z
- **Completed:** 2026-11-07T08:47:34Z
- **Tasks:** 2 completed.
- **Implementation/test files:** 9, plus this summary and the project tracking updates.

## Accomplishments

- Added checked `.type3D` / `.r32Float` private ping/pong textures for cell-centred dye and staggered `u`, `v`, and `w`, including per-component extents, device-aligned row/image staging, exact uploads/readbacks, full-volume clears, typed errors, and finite-input validation.
- Added the independent three-lane ABI: 48-byte stride, 16-byte alignment, and offsets `0/16/32`. The actual Metal round-trip preserves every lane exactly.
- Added production `fluid3DAdvectVelocity`, `fluid3DAdvectDye`, and `fluid3DEnforceWalls` kernels. Velocity components use their own staggered coordinates and all read the same old velocity generation; exact wall enforcement completes before generation swaps, and dye then uses the transported velocity.
- Added production harness fixtures on asymmetric `8x7x6` and production `64x64x64` domains. The harness loads the freshly built app `default.metallib`, uses Metal validation, rejects missing device/library/pipeline and malformed fixtures, and records commands, toolchain, device/OS, source hashes, contract hashes, and metallib hash in `.build/fluid3d-evidence/`.
- Added configuration checks for positive finite inverse spacing and domain extents. Test-first checks demonstrated that tiny positive spacing and overflowing spacing were accepted before the guard and are now rejected.
- Added the Python GPU-test driver to the evidence source-hash manifest. A regression test failed before it was included and passes with the final evidence.
- Registered the new Swift/Metal files once in both app targets and the compiling Mac state-test target. No established 2D production source, `StaticData`/`BufferData` ABI, or 2D shader entry point changed.

## Production API and Shader Bindings

`FluidSimulation3D(metal:configuration:)` throws on resource or pipeline failures. `encodeClear(command:)`, `encodeWalls(command:)`, and `encodeAdvection(command:)` operate on caller-owned command buffers; the caller serializes mutations. The production configuration is fixed at `64³`, `h=1/64`, and `dt=1/60`; the smaller-grid factory is test-only and bounded to dimensions `1...64`.

| Kernel | Buffer bindings | Texture bindings |
|---|---|---|
| `fluid3DABIRoundTrip` | `0`: input uniforms; `1`: output uniforms | — |
| `fluid3DClear` | — | `0`: output volume |
| `fluid3DAdvectVelocity` | `0`: `Fluid3DUniforms` | `0...2`: old `u/v/w`; `3`: selected component input; `4`: selected component output |
| `fluid3DAdvectDye` | `0`: `Fluid3DUniforms` | `0...2`: transported `u/v/w`; `3`: old dye; `4`: output dye |
| `fluid3DEnforceWalls` | `0`: `Fluid3DUniforms` | `0`: selected velocity generation, read/write |

## Verification

- `xcrun metal --version` — **PASS**, Apple Metal `32023.922` (Metal Toolchain 27.2).
- `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` — **PASS**.
- `xcodebuild -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetaliOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` — **PASS**.
- `python3 -m unittest Tests.Integration.test_fluid3d.Fluid3DTests.test_storage_and_abi Tests.Integration.test_fluid3d.Fluid3DTests.test_advection_and_boundaries` — **PASS**, 2 production GPU tests. Storage checked 5,960 exact values; ABI was 48 bytes / alignment 16 / offsets `0,16,32`.
- The advection GPU fixture compared **1,075,764** output values across 11 fixtures. Overall maximum absolute error was `2.11394384e-7`; production `64³` maximum error was `1.53854034e-7`, against `2e-5 + 2e-4*abs(reference)`. Every fixture was finite, dye remained in `[0,1]`, and every normal wall face was exactly zero.
- `python3 -m unittest discover -s Tests/Integration` — **PASS**, 19 tests in 93.271 s, including the 2D GPU/renderer regressions and both 3D CPU-reference feasibility checks.
- `xcodebuild test -project FluidDynamicsMetal.xcodeproj -scheme FluidDynamicsMetalOSX -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` — **PASS**, 34 tests total: 25 state tests and 9 Mac HUD UI tests, zero failures. Result bundle: `Test-FluidDynamicsMetalOSX-2026.11.07_08-53-25-+0000.xcresult`.
- `git diff --check` — **PASS**.

GPU evidence was collected on **Apple M3 Pro**, **macOS 27.0 (26A428)** with the app's actual production metallib. Contract-prefix SHA-256: `a7768571a996d5b9520aff5095100bb52fb67f96560f99633d081c04a3a9e01b`; base CPU manifest SHA-256: `b7042898c88e3872699de8e8d3fcdc3da20cbfc8c21fe31ac7fe11e0188ec7e0`; advection fixture manifest SHA-256: `6f6d4fc297a3e20c867cca99728fcf20c369148b3edff268e370b80025d96330`; `default.metallib` SHA-256: `cf2820e6d65dd831d2ff2fb8228e8648e422c50c5f1954a1e9fb3774eb382de3`.

Source SHA-256 values recorded by the final GPU evidence:

| Source | SHA-256 |
|---|---|
| `Sources/Shared/FluidSimulation3D.swift` | `28333fd714fa2d2557ed1d4af0b02a82480b78d78914479027b792055b6f70ab` |
| `Sources/Shared/MetalDevice.swift` | `db1c5649d1c2653717fecf5059bc030d8f6ae53b0948edefa7e0c2aca58674b2` |
| `Sources/Shared/Shaders3D.metal` | `b754de681805d5c3b5b9db5aa4af595028a3bf24ff7d70a9f526a951f08e5388` |
| `Sources/Shared/SimulationTypes3D.swift` | `5ff91ef28fc27be52d76f735a0cb4637a8e69fa0efe919450cba9895974fe8ac` |
| `Sources/Shared/VolumeField3D.swift` | `1ac85a14b59ff41fb86b08237acda2f0c5f6ff06fd610215af36cf2e4fb74dd6` |
| `Tests/Integration/fluid3d_reference.swift` | `abf33d779fbeb427b6a22f5239cd4ef98c120bbcbee268fe5a7629887f3df691` |
| `Tests/Integration/test_fluid3d.py` | `c91a3e4c3181413478123ed60c9ffe5444ce2d46686cd32e647a66b1850feb12` |
| `Tests/Integration/test_fluid3d.swift` | `49e5ad4fea89aa621a0682f796fbcdc33c9291795b3be17ea0ca23cae62a10c9` |

Evidence files: `.build/fluid3d-evidence/storage-abi.json` and `.build/fluid3d-evidence/advection-boundaries.json` (generated build artifacts, intentionally untracked).

## Inline Review and Deviations

An inline review checked the plan's artifacts, failure behavior, binding map, target membership, old-generation ordering, boundary semantics, numerical tolerances, 2D scope, and test evidence. It found two in-scope provenance/configuration gaps: extreme finite spacing could create nonfinite shader uniforms/extents, and the evidence source list omitted its Python driver. Both were addressed test-first and the full relevant verification was rerun. This was an inline review, not independent-agent verification. The preregistered numerical contract and its tolerances were unchanged.

## Requirement Status and Next Plan

`07-02` supplies storage/ABI and advection prerequisites; it does not implement compatible pressure projection, production reset/step, or user-facing renderer integration. Therefore **no phase requirements are marked complete**: `SIM-05` and `VER-03` remain pending, as do all other Phase 7 requirements, until end-to-end production behavior is verified. Continue sequentially with `07-03`; preserve the explicit human visual/interaction approval gate at `07-09`.

## Self-Check

- Both target builds, both actual-metallib GPU fixtures, the full 19-test integration suite, the 34-test Mac scheme, and `git diff --check` passed on the final implementation.
- Final GPU evidence hashes all production/reference sources and the Python fixture driver; it records the fresh metallib and locked contract hashes.
- No Phase 7 requirement checkbox was changed by this plan.

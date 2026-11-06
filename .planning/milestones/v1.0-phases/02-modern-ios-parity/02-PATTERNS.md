# Phase 2 — Existing Code Patterns

**Mapped:** 2026-09-24
**Scope:** iOS build, simultaneous touch input, shared GPU uniforms and parity evidence.

| Planned file / role | Closest existing analog | Data flow / constraint |
|---------------------|-------------------------|------------------------|
| `FluidDynamicsMetal.xcodeproj/project.pbxproj` — iOS settings | Mac target Debug/Release configurations modernized in Phase 1 (`MACOSX_DEPLOYMENT_TARGET=26.0`, `SWIFT_VERSION=5.0`) | iOS target and project Debug/Release still override with iOS 10.x / Swift 4. Update all effective iOS configurations, do not regress Mac. |
| `FluidDynamicsMetaliOS/Info.plist` — installability | Existing storyboard/full-screen iOS bundle; `01-BASELINE.md` bundle inspection | `armv7`-only capability predates modern hardware; verify `MinimumOSVersion=26.0` and the Metal library in the built `.app`. |
| `FluidDynamicsMetaliOS/RenderViewController.swift` — touch identity/gestures | Mac controller's down/drag/up → `Renderer.updateInteraction`; existing iOS double-tap recognizers | Maintain active contacts independent of changed-event sets; stable per-finger slots and local MTKView coordinates, recognizing shortcuts before committing tap dye. |
| `Shared/Renderer.swift` — contact snapshot and frame uniforms | `updateInteraction(points:in:)`, `nextBuffer`, `draw(in:)`, and `StaticData` | Preserve Mac single-pointer forwarding, use all live iOS contacts and zero GPU uniforms on release; new touches must have zero initial velocity. |
| `Shared/Shaders.metal` — GPU contact slots | `BufferData.positions[5]`, `.impulses[5]` and `for (int i=0; i<5; ++i)` in `applyForceVector` / `applyForceScalar` | If contact capacity changes, update Swift and Metal together and keep byte offsets for subsequent fields aligned. Maintain numerical defaults and shader entry-point names. |
| `.planning/phases/02-modern-ios-parity/02-PARITY.md` — observational record | `01-BASELINE.md` Phase 1 result table | Record device/runtime, actual PASS/FAIL/NOT TESTED for iPhone, iPad, gestures, Mac reference; do not promote simulator to physical multi-touch evidence. |

No new third-party framework or separate shared module is needed; `Shared/` files belong to both native targets.

# Codebase Review — Findings

**Date:** 2026-09-26
**Scope:** All sources under `Sources/`, tests under `Tests/`, project settings, build script.
**Method:** Full read of every Swift/Metal source file, unit/UI/integration tests, `project.pbxproj` build settings, and `build-macos.sh`. Static analysis only; no runtime verification performed.

---

## Summary

The codebase is in good shape overall. The state model (`SimulationState` / `SimulationTuning`) is clean and well unit-tested, Swift 6 concurrency is handled correctly, and the frame-synchronization discipline (semaphore ring buffer, resize draining in-flight frames) is sound. The issues below are mostly accumulated dead code from the project's earlier "MetalImage" lineage, latent (not-yet-triggered) bugs, duplicated HUD logic across platforms, and robustness gaps around error handling.

Severity counts: **3 High-priority latent bugs**, **6 architecture/debt items**, **3 robustness items**, **8 hygiene items**.

---

## 1. Latent bugs / correctness

### 1.1 Pipeline cache key omits pixel format — HIGH (latent)
`Sources/Shared/MetalDevice.swift:74`

The render-pipeline cache key is `vertexFunctionName + fragmentShaderName`, ignoring `pixelFormat`. Today every fragment shader name is used with exactly one pixel format, so no collision occurs. But if any fragment shader is ever instantiated at a second pixel format (e.g., reusing `resampleField` for an RGBA field), `MetalDevice.createRenderPipeline` returns the first-created cached pipeline with the wrong color-attachment format, which fails pipeline creation or produces incorrect output — silently.

**Fix:** Include `pixelFormat.rawValue` in the cache key.

### 1.2 Closing the Mac window leaves the app running with no UI — HIGH
`Sources/macOS/RenderViewController.swift:156` (`windowShouldClose`), `Sources/macOS/AppDelegate.swift:24`

`windowShouldClose` calls `orderOut(_:)` and returns `false`, so the window is hidden, never closed. `applicationShouldTerminateAfterLastWindowClosed` therefore never fires, and the app keeps running with no visible window and no way to reopen one (there is no "New Window" item in the menu). The app is only recoverable via Quit.

**Fix:** Either return `true` from `windowShouldClose` (and keep the panel-close side effect), or add a menu item / re-open mechanism.

### 1.3 Inconsistent (0,0) contact sentinel handling — MEDIUM
`Sources/Shared/Renderer.swift:392` vs. `Sources/Shared/Renderer.swift:216`

Zero is the shader's unused-slot sentinel. `Renderer.writeContacts` deliberately preserves a genuine contact at the origin by nudging it to `(0.01, 0.01)`. However, the macOS mouse-drag path in `draw(in:)` filters out exact-(0,0) points *before* contacts are constructed (`filter { $0.element.x != 0 || $0.element.y != 0 }`), so on macOS a contact at the exact corner pixel is silently dropped and the nudge in `writeContacts` can never apply. Two layers enforce the same sentinel with different rules.

**Fix:** Filter in one place only (ideally inside `writeContacts` alongside the nudge), or use an explicit count/validity field instead of a magic sentinel.

### 1.4 Slab textures never cleared at creation — LOW
`Sources/Shared/Slab.swift:24-25`

`makeTexture` contents are formally undefined. Startup correctness currently relies on driver zero-fill of the velocity/density/pressure slabs. This is true on Apple Silicon in practice, but is not guaranteed by the API.

**Fix:** Encode a one-time clear (or `memset` for shared storage) when allocating slabs, at least on first initialization.

---

## 2. Dead code / model–renderer divergence

### 2.1 Dead files still compiled into targets — MEDIUM
- `Sources/Shared/ComputeShader.swift` — entire class never instantiated anywhere (app or tests). Header says "BasicFilter.swift / MetalImage".
- `Sources/iOS/Protocols.swift` — `ImageSource`, `ImageConsumer`, generic `Targets`, and the `-->` operator are referenced only within this file; compiled into the iOS target. The generic parameter `Targets<T: Comparable, ImageConsumer>` shadows the protocol name, which is confusing to read.

**Fix:** Delete both files (and remove from the Xcode project), or move to a clearly-labeled vendor/legacy location if they are kept intentionally.

### 2.2 Dead members in live files — MEDIUM
- `MetalDevice.queue`, `activeCommandBuffer`, `swapBuffers()`, `inputTexture`, `outputTexture` (`Sources/Shared/MetalDevice.swift:22-31,56-60`) — no callers.
- `RenderShader.calculateWithCommandBuffer(buffer:texture:configureEncoder:)` non-indexed variant (`Sources/Shared/RenderShader.swift:35`) — no callers.
- `Renderer.initSurfaces(width:height:)` (`Sources/Shared/Renderer.swift:175`) — never called; slab creation actually happens inline in `mtkView(_:drawableSizeWillChange:)`.
- Global `let MaxBuffers = 3` in `Sources/iOS/RenderViewController.swift:12` — shadows/duplicates `Renderer.MaxBuffers`; unused.
- `PipelineStateConfiguration` mixes compute and render concerns in one struct with a `computeShader` field that render shaders set to `""`.

### 2.3 Tuning fields the renderer never reads — MEDIUM
`Sources/Shared/SimulationState.swift:32-43` vs. `Sources/Shared/Renderer.swift:424`

`SimulationTuning.radius` (bounded 1–400, unit-tested) and `pressureIterations` (bounded 1–80, unit-tested) have no effect: `Renderer.draw` hardcodes `for _ in 0..<40`, and the splat radius comes from `touchRadius ?? 150 / ScreenScaleAdjustment`, not from tuning. `SimulationState.resetTuning()` also has no caller. The UI exposes only Force/Dye/Swirl/Fade. The model documents behavior the renderer does not implement.

**Fix:** Either wire these fields through (pressure iterations is the interesting one for quality/perf tuning) or remove them until needed.

### 2.4 Effectively dead constant — LOW
`Renderer.ScreenScaleAdjustment` (`Sources/Shared/Renderer.swift:42`) is documented as an adjustable knob ("reasonable values [0.5, 3.0]") but is fixed at 1.0; the radius/position arithmetic around it (`150 / scale`, `150 * scale * scale`) is untested for any other value and easy to break silently.

---

## 3. Architecture

### 3.1 ~200 lines of HUD logic duplicated per platform — MEDIUM
`Sources/macOS/RenderViewController.swift` and `Sources/iOS/RenderViewController.swift` each implement `fieldTitle`, `refreshControls`, `refreshTuningValues`, and a layout heuristic with parallel but subtly different magic numbers (e.g., macOS height thresholds 176/284/440 vs. iOS content-height formula). Any behavior change (new field, new control, label change) must be made twice and kept consistent by hand.

**Fix:** Extract the platform-independent parts (field titles, percent formatting, refresh sequencing, column-count decision) into `Sources/Shared` (e.g., a `HUDViewModel`), leaving only view construction per platform.

### 3.2 `Renderer` is a god object — MEDIUM
`Sources/Shared/Renderer.swift` (~500 lines) owns input buffering (`positions`, `directions`, `touchContacts`, `pendingTapContacts`), tuning state, shader/pipeline setup, slab lifecycle, resize/resample, the simulation step ordering, and `MTKViewDelegate`. Unit tests can only reach the two `nonisolated static` helpers as a result.

**Fix:** Split input buffering and the fluid-step pipeline (slab graph + pass ordering) into their own types; this also makes the resize path testable.

### 3.3 Fragile Swift↔Metal ABI coupling — MEDIUM
`StaticData` (`Sources/Shared/Renderer.swift:19-29`) must stay layout-identical to `BufferData` (`Sources/Shared/Shaders.metal:58-69`). This is enforced by convention only — AGENTS.md warns about it; no test asserts it. `writeContacts` also binds a tuple's bytes as `[SIMD2<Float>]` via `withUnsafeMutableBytes`, which works but is fragile under refactoring (e.g., anyone reordering fields or changing the tuple sizes compiles fine and corrupts the GPU-side layout).

**Fix:** Add a unit test asserting `MemoryLayout<StaticData>` offsets/stride against the documented Metal layout (or a fixed 208-byte contract), and a comment cross-referencing both sides.

### 3.4 Redundant double caching — LOW
`MetalDevice.pipelineCache` (NSCache) plus each `RenderShader` holding its own strong `renderPipelineState`. With one `Renderer` per process the NSCache layer adds nothing except a second code path; NSCache eviction is also pointless when every client holds a strong reference.

### 3.5 Per-frame buffer allocation for >10 contacts — LOW
`Sources/Shared/Renderer.swift:412` allocates a fresh `MTLBuffer` via `makeBuffer(bytes:)` for every contact batch beyond the first, inside `draw(in:)`. With 11+ concurrent contacts this is a per-frame heap + GPU allocation. Should come from the existing ring or a small dedicated pool.

---

## 4. Robustness / error handling

### 4.1 Force unwraps on all Metal object creation — MEDIUM
`MetalDevice.init` (`MTLCreateSystemDefaultDevice()!`, `makeCommandQueue()!`, `makeDefaultLibrary()!`), `createTexture` (`makeTexture!`), `newCommandBuffer()` (`!`), `MetalDevice.buffer` (`!`), and the per-batch `makeBuffer!` in `draw`. On a device/simulator without Metal support, or under allocation failure, the app traps with no user-facing message.

**Fix:** Fail soft at the app-entry layer (present an "unsupported device" state) rather than trapping inside a singleton initializer.

### 4.2 Silent pipeline failures — MEDIUM
`RenderShader.configurePipeline` catches errors with `print("Could not create render pipeline state.")` (`Sources/Shared/RenderShader.swift:95`), and `calculateWithCommandBuffer` silently no-ops when `renderPipelineState` is nil. A typo'd shader entry-point string (the names are string literals resolved at runtime — `Renderer.swift:59-70`) yields a blank/partially-blank simulation with only a console message. Leftover debug `print("Deinit Filter")` in both shader wrappers.

**Fix:** Surface pipeline-creation failures prominently (assert in DEBUG, logging in Release) and remove the deinit prints.

### 4.3 Misleading `VertexIn` attribute annotations — LOW
`Sources/Shared/Shaders.metal:12-15` declares `[[attribute(0)]]` / `[[attribute(1)]]`, but the vertex function takes `constant VertexIn* [[buffer(0)]]` and no vertex descriptor is ever set (attributes only apply to `[[stage_in]]`). The annotations are dead and suggest a wiring that does not exist.

---

## 5. Hygiene

| # | Item | Location |
|---|------|----------|
| 5.1 | Typo: `avaliableBufferIndex` → `availableBufferIndex` | `Renderer.swift:90` |
| 5.2 | `.DS_Store` present under `Sources/`; `.gitignore` lacks a `.DS_Store` entry (currently saved only by contributors' global ignores) | repo root |
| 5.3 | Empty `output/` directory at repo root | `output/` |
| 5.4 | `UIButton.contentEdgeInsets` deprecated since iOS 15 while the target is iOS 26; use `UIConfiguration`-based insets | `Sources/iOS/RenderViewController.swift:105` |
| 5.5 | `preferredFramesPerSecond = 60` hardcoded; no ProMotion 120 / `preferredFrameRateRange` | `Renderer.swift:103` |
| 5.6 | Space/S keyboard shortcuts on macOS exist only as raw key codes, not menu items with key equivalents (documented in README, but undiscoverable in-app; HIG expects menu equivalents) | `Sources/macOS/RenderViewController.swift:426-435` |
| 5.7 | Integration tests named after legacy milestone phases (`test_phase02/03/05`) — opaque to new contributors | `Tests/Integration/` |
| 5.8 | `mtkView(_:drawableSizeWillChange:)` ignores its `size` parameter and reads `view.bounds` instead; correct today (grid is defined in points) but relies on an unstated invariant | `Renderer.swift:443-448` |

---

## 6. Test-coverage observations

- **Well covered:** `SimulationState`/`SimulationTuning` semantics (bounds, non-finite inputs, fade round-trip, pause/inactivity interplay) and `Renderer` contact batching/sentinels.
- **Gaps:** no test asserts the Swift↔Metal `StaticData`/`BufferData` layout contract (3.3); HUD layout heuristics are private and view-coupled, hence untestable without extraction (3.1); resize/resample path has no unit-level coverage; `RenderShader`/`MetalDevice` (including the cache-key bug 1.1) have no tests.

---

## 7. Strengths (for balance)

- Clean, value-type simulation state with thorough unit tests.
- Correct Swift 6 concurrency: `@MainActor` isolation throughout, `nonisolated` statics for testable helpers, `isolated deinit`, and completion handlers that capture only the thread-safe semaphore.
- Careful frame synchronization: ring of `MaxBuffers` uniform buffers gated by a semaphore, and resize drains all in-flight frames before replacing textures.
- Good accessibility coverage on both HUDs (labels, values, hints, reduce-transparency handling, dynamic type on iOS).
- Sensible `build-macos.sh` with guarded clean/rebuild and a validated copy step.

---

## Suggested remediation order

1. **Quick correctness wins:** 1.1 (cache key), 1.2 (window close), 1.3 (sentinel), 4.2 (fail loudly on pipeline errors).
2. **Dead-code sweep:** 2.1, 2.2, 5.3 — mechanical, shrinks both targets.
3. **Contract hardening:** 3.3 layout test, 2.3 resolve or remove unused tuning fields.
4. **Structural (larger, schedule deliberately):** 3.1 HUD extraction, 3.2 Renderer decomposition, 4.1 graceful Metal-unavailable path.

# Phase 8 — Implementation Pattern Map

**Mapped:** 2026-11-13 · **Method:** inline inspection of live source, not independent-agent research.

## Ownership and data flow

`AppKit controls / canvas events → Renderer inspection mutators → SimulationState.inspection3D → Camera3D + FieldVisualization3D → drawable`

`accepted logical step → FluidSimulation3D.encodeStep → returned projection status + new u/v/w → TracerSystem3D.encodeAdvance → consumeStep → asynchronous completion validation`

The first path must never write the second path's evolution resources. Both app targets compile shared files directly; only Mac exposes the new controls.

| Planned file / role | Closest live analog | Reuse / difference |
|---|---|---|
| `Sources/Shared/InspectionState3D.swift` — pure presentation values | `Sources/Shared/SimulationState.swift:109–149` | Finite/bounded values, Equatable state; do not reuse 2D DisplayOptions or adjustment/reset semantics. |
| `Sources/Shared/Camera3D.swift` — pure transforms and fit | `Renderer.viewport(in:)`, `FieldVisualization3D.encodeSlice` | These currently fit 2D squares, not a 3D camera. Implement the approved full-aspect fit/matrix contract, with independent projections. |
| `SimulationState.swift` / `Renderer.swift` — ownership, restart, scheduling | `Renderer.swift:225–292,369–426` | Candidate resources commit after validated reset; logical steps encode before consume and before drawable acquisition. Preserve inspection only on Restart, not initial entry/reselection. |
| `FieldVisualization3D.swift` / `Shaders3D.metal` — spatial sheet/cube/marker render | Existing fixed-slice path and palette | Retain explicit legacy `encodeSlice` for Phase 7 fixtures/benchmark. Add separate depth-equipped spatial path; dedicated throwing pipelines avoid changing the 2D pipeline cache contract. |
| `TracerSystem3D.swift` — passive evolution | `ParticleSystem.swift`; production MAC sampler | Reuse responsibility separation only. Positions are float4, not float2; no trails, packed-2D velocity, fatal-error allocation or render-driven update. |
| `PressureProjection3D.swift` — read-only status binding | `StatusSlot` at lines 46–61 | Status buffer is fileprivate. Add narrow binding/readback access; do not expose writable diagnostics or read status before completion. |
| `Sources/macOS/RenderViewController.swift` — native inspection UI | `installControls`, tuning slider rows, `refreshControls`, local key monitor | Preserve panel, pinned transport, wrapping, menu identities and focus-first behavior. Add distinct inspection refresh rather than rebuilding layout every running step. |
| `Sources/macOS/InspectionSlider3D.swift` — native keyboard increments | Existing continuous NSSlider | Small NSSlider subclass for focused arrow increments only; preserve native pointer/AX adjustment and do not install global camera arrows. |
| `Sources/macOS/OrientationGuide3DView.swift` — corner orientation | Native `ColourLegendView` in Mac controller | Use native text drawing and camera rotation; hit-test through, no focus, one nonactionable AX element. |
| `Tests/Integration/inspection3d_reference.swift` / `test_inspection3d_reference.py` — independent oracle | `fluid3d_reference.swift` / reference Python driver | Small independent Double fixture engine, no production imports/Metal; analytic slice and RK2 expectations. Does not replace the Phase 7 oracle. |
| `Tests/Integration/test_inspection3d_state.{swift,py}` — fast production math/state tests | Standalone Swift compilation pattern in integration drivers | Compile only required pure production sources, no metallib/Xcode/UI launch; test camera, clamping and operation scopes early. |
| `Tests/Integration/test_fluid3d.{swift,py}` — production GPU checks | Existing selector dispatch, fresh-metallib validation, readback and evidence | Register each new selector and Python unittest together. Version Phase 8 evidence separately; preserve historical benchmark meaning. |
| Xcode and standalone inventories | `project.pbxproj`, `SWIFT_SOURCES`, other integration source lists | New shared files enter both apps and any direct-source state target; Mac-only helpers enter Mac target only. All three renderer harness lists must include new Renderer dependencies. |

## Concrete patterns to preserve

### Encode before consume, not per drawable

From `Sources/Shared/Renderer.swift:383–399`:

```swift
threeDStatus = try simulation3D.encodeStep(command: command)
// New tracer advance belongs here, before consumeStep and currentDrawable.
guard state.consumeStep() else { /* existing failure path */ return }
encoded3DStepCount += 1
```

The live method handles failure by committing already-encoded work, releasing semaphore slots through completion, draining, then recovering to 2D. Preserve that unwind rather than returning with an acquired semaphore slot or publishing a partial session.

### Immutable submission values

From `Sources/Shared/FieldVisualization3D.swift:143`:

```swift
encoder.setFragmentBytes(&palette, length: MemoryLayout<PaletteUniforms>.stride, index: 0)
```

Use encoder-copied constants or retained per-command resources for camera/tracer uniforms. Never overwrite a shared CPU-visible uniform allocation still consumed by one of three queued commands.

### Production MAC reconstruction

From `Sources/Shared/Shaders3D.metal:189–192`:

```metal
return float3(
    sampleLattice(u, position, float3(0.0f, 0.5f, 0.5f), spacing, domainCells, 0),
    sampleLattice(v, position, float3(0.5f, 0.0f, 0.5f), spacing, domainCells, 1),
    sampleLattice(w, position, float3(0.5f, 0.5f, 0.0f), spacing, domainCells, 2));
```

New forward tracer RK2 calls this helper with the newly projected current textures; do not call the existing negative-sign dye backtrace as a forward trajectory integrator.

### Focus isolation

From `Sources/macOS/RenderViewController.swift:121–124`:

```swift
if event.keyCode == 0x31, let button = event.window?.firstResponder as? NSButton {
    button.performClick(nil); return nil
}
if event.window?.firstResponder is NSControl || event.window?.firstResponder is NSTextView { return event }
```

Variable name above is expanded for readability; original monitor uses `$0`. Extend native segment/slider handling without routing control-focused Space/arrows to canvas transport. Existing mouse handling is behind `shouldAdvance`; the paused 3D branch must precede that 2D guard.

## Readback gaps that must not be copied

- `scanSimulation` stages/finite-checks reduction workspace but does not return it for equality comparison.
- `encodeSimulationSnapshot` includes workspace but not the simulation failure latch, projection standalone latch, tracer resources or renderer counters/status ownership.
- `StatusSlot.diagnosticStateValues()` requires command completion; CPU reads before queue completion are not GPU-state evidence.
- Enumerate every allocated evolution resource, including any optional trace allocation when enabled, with stable names/shapes/lengths. Diagnostic metadata is not a substitute for staging GPU bytes.

## Scope and hazards

- Keep the fixed 64³ solver, 320 cap, acceptance thresholds, 2D solver/ABI and immutable numerical-contract prefix.
- Retain the old fixed-square benchmark explicitly; new spatial images are not `solverAndFixedSlice` measurements.
- UI-SPEC now exists and supplies all camera/guide/tracer constants. Research's older missing-UI warning is resolved, not a reason to repeat discuss/UI workflows.
- Resource exhaustion, invalid matrices and cross-window events require negative tests; no new network, authentication or imported-file surface is introduced.

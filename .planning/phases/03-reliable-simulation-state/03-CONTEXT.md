# Phase 3: Reliable simulation state - Context

**Gathered:** 2026-09-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the existing Mac and iOS fluid simulation reliable through view resize/rotation, pause/resume, and iOS inactivity/return. Add automated checks for field and pause transitions and bounded/default/reset state ahead of future tuning controls. Keep the current solver character and existing shortcuts. Named on-screen controls belong to Phase 4; live tuning belongs to Phase 5; the resolution control and visible reset control belong to Phase 6.

</domain>

<decisions>
## Implementation Decisions

### Fluid across resize
- **D-01:** Preserve the fluid already on screen when the Mac window resizes or an iOS view rotates/resizes; do not replace it with a fresh canvas. Fit the full fluid pattern to the new canvas even when its aspect ratio changes significantly.
- **D-02:** Interaction must remain usable immediately at the new size, including a drag in progress across a live resize/rotation; avoid stale-position impulses or stranded forces.
- **D-03:** Resizing while paused keeps the simulation paused and the fluid frozen but visibly adapted to the new canvas; resuming continues from that state.

### Paused display and input
- **D-04:** A field change while paused updates the visible field immediately without advancing the fluid. Keep the selected field through pause, resume, and resize.
- **D-05:** Ignore touch/mouse input while paused: do not queue forces or deposit dye for later. If a drag begins during pause and is still held when the user resumes, subsequent movement starts from its current position without a sudden impulse.

### iOS inactivity and return
- **D-06:** On return, restore the user's prior running/paused choice. A user-paused simulation stays paused; one that was running resumes.
- **D-07:** Keep the visible fluid pattern and selected field across a brief background/foreground trip. Background time does not count as simulation time or trigger a catch-up jump.
- **D-08:** Clear interrupted/stale touches on inactivity so that fresh touches can stir immediately after return without leftover forces.

### Automated state checks
- **D-09:** Exercise the complete field cycle, starting on density and visiting pressure, velocity, and vorticity before returning to density.
- **D-10:** Check the running → paused → field switch while paused → resumed transition, including retention of the selected field.
- **D-11:** Check shared tuning-state defaults and bounds before the controls exist; cover values outside the allowed bounds according to the chosen state contract. Also check that changing values and invoking a state-level reset restores defaults. The visible reset control remains Phase 6 work.

### Agent's Discretion
Choose the state representation, automated test framework, concrete parameter bounds, how out-of-range values are handled, and GPU resize/preservation technique during research and planning. Preserve the existing default solver appearance/values and the decisions above.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and locked continuity
- `.planning/ROADMAP.md` §Phase 3 — goal, SIM-02/SIM-03/VER-01 success criteria, and later-phase boundaries.
- `.planning/REQUIREMENTS.md` — SIM-02, SIM-03, VER-01; CTRL-01–CTRL-07 are later-phase requirements.
- `.planning/PROJECT.md` — platform baselines, preservation of familiar fluid behavior, and no intentional solver redesign.
- `.planning/phases/02-modern-ios-parity/02-CONTEXT.md` — previously chosen gestures, default density field, full iOS canvas, and visual parity expectations.
- `.planning/phases/01-modern-mac-baseline/01-BASELINE.md` — baseline field order, default solver look/values, and Mac interaction reference.

### Architecture and integration
- `.planning/codebase/ARCHITECTURE.md` — shared renderer/Slab responsibilities and existing resize path; verify against live code because this map predates Phase 2.
- `.planning/codebase/STRUCTURE.md` — target source locations and project source-list integration; verify current Xcode settings in the project because maps predate modernization.

No external specs or ADRs were supplied for this phase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Shared/Renderer.swift`: owns field selection, contacts, buffers, the GPU frame sequence, and the `MTKViewDelegate` size-change callback; shared by both targets.
- `Shared/Slab.swift`: ping/pong GPU textures for the five simulation fields, including retained pressure; existing state container relevant to resize continuity.
- `Shared/RenderShader.swift` and `Shared/MetalDevice.swift`: existing render-pass and GPU allocation machinery.
- `.planning/phases/01-modern-mac-baseline/01-BASELINE.md`: default values and field order against which state checks can assert continuity.

### Established Patterns
- Both storyboard-backed controllers install `Renderer` as the `MTKView` delegate and forward input into it. Mac Space/S and iOS double-tap shortcuts already toggle pause/cycle fields.
- `Renderer.mtkView(_:drawableSizeWillChange:)` currently recreates all slabs and uniform buffers from `view.bounds`, losing the previous GPU fields on resize. The renderer cycles display indices 0–3 and advances simulation during `draw(in:)`.
- The iOS controller currently sets `metalView.isPaused = true` on resigning active and `false` on becoming active, regardless of a previous manual pause. Paused `MTKView` drawing may require an explicit display refresh to show a new field.
- There is no automated test target. Shared Swift files are compiled directly into both app targets; `StaticData` in Swift must match `BufferData` in Metal when changing uniforms.

### Integration Points
- `FluidDynamicsMetalOSX/RenderViewController.swift`: Mac window input and Space/S shortcuts.
- `FluidDynamicsMetaliOS/RenderViewController.swift`: multi-touch bookkeeping, iOS gestures, and application activity notifications.
- `FluidDynamicsMetal.xcodeproj/project.pbxproj`: any shared source or test target needs explicit project membership.
- `Shared/Shaders.metal`: shader contract and solver defaults to preserve if resize/state work affects texture sampling or uniform layout.

</code_context>

<specifics>
## Specific Ideas

- During portrait/landscape changes, fit the entire previous fluid image to the new canvas even if that stretches it.
- A paused view should be inspectable: switching fields shows the new field immediately while motion remains frozen.
- A drag held across resume begins from the current position instead of producing a jump from coordinates captured before the pause.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Existing Phase 1 macOS 26 runtime verification remains deferred to milestone closeout; Phase 2 physical multi-touch follow-up remains unverified/device-only per prior context.

</deferred>

---

*Phase: 3-reliable-simulation-state*
*Context gathered: 2026-09-24*

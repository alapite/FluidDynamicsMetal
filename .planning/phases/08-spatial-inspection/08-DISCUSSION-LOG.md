# Phase 8: Spatial Inspection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-13
**Phase:** 08-spatial-inspection
**Areas discussed:** Camera feel and recovery; spatial orientation cues; slice selection and depth; tracer appearance and defaults.

## Area selection

**Question:** Which areas would you like to discuss for Phase 8? Select all that matter to you.

| Option | Description | Selected |
|--------|-------------|----------|
| Camera feel and recovery | Orbit/zoom interaction, initial view and camera reset scope | ✓ |
| Spatial orientation cues | Bounds and X/Y/Z directions without clutter; Phase 7 had no guides | ✓ |
| Slice selection and depth | Plane choice, depth readout and switching behaviour | ✓ |
| Tracer appearance and defaults | Distribution, prominence and initial visibility; no trails | ✓ |

**User's choice:** All four areas.

## Camera feel and recovery

### Initial camera view

| Option | Description | Selected |
|--------|-------------|----------|
| Slightly angled (Recommended) | Modest three-quarter view reveals the slice in 3D while retaining readable dye | ✓ |
| Face-on XY | Preserve flat opening; learners orbit to explore | |
| You decide | Choose clearest view during visual validation | |

**User's choice:** Slightly angled (Recommended).

### Direct camera interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Drag + zoom (Recommended) | Plain drag orbits fixed centre; wheel/two-finger scroll zooms; no modifier/panning | ✓ |
| Modifier-drag + zoom | Option-drag orbits; unmodified dragging does nothing; scroll zooms | |
| You decide | Discoverable mouse/trackpad gestures isolated from controls/input | |

**User's choice:** Drag + zoom (Recommended).

### Orbit constraints

| Option | Description | Selected |
|--------|-------------|----------|
| Upright orbit (Recommended) | Horizontal orbit, bounded vertical tilt, no roll; zoom remains outside volume | ✓ |
| Free tumble | Upside-down views and arbitrary rotation, with reset for recovery | |
| You decide | Choose understandable camera limits | |

**User's choice:** Upright orbit (Recommended).

### Reset Camera scope

| Option | Description | Selected |
|--------|-------------|----------|
| Camera only (Recommended) | Initial angle/fitted zoom; leave slice/depth/tracers/playback/step count alone | ✓ |
| All inspection settings | Restore all inspection defaults without restarting | |
| You decide | Choose least surprising recovery and label it accordingly | |

**User's choice:** Camera only (Recommended).

**Continuation question:** More camera questions, or move on? Remaining areas were listed.
**Options:** Next area (save and discuss orientation); More questions (refine camera).
**User's choice:** Next area.

## Spatial orientation cues

### Spatial frame

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle cube (Recommended) | Thin subdued wireframe volume bounds around slice; no floor grid/solid walls | ✓ |
| Slice outline only | Outline plane but omit full volume bounds | |
| You decide | Lightest readable spatial framing | |

**User's choice:** Subtle cube (Recommended).

### Axis identification

| Option | Description | Selected |
|--------|-------------|----------|
| Small axis guide (Recommended) | Noninteractive corner X/Y/Z guide rotates with view; panel names plane/depth | ✓ |
| Labels on cube | Axis labels on frame, adding text near dye | |
| You decide | Readable unobtrusive cue | |

**User's choice:** Small axis guide (Recommended).

### Looking behind the slice

| Option | Description | Selected |
|--------|-------------|----------|
| Visible both sides (Recommended) | Geometrically consistent two-sided plane; no billboarding; edge-on thinness acceptable | ✓ |
| Front side only | Hide reverse side; recover with orbit/reset | |
| You decide | Clearest honest fixed-plane depiction | |

**User's choice:** Visible both sides (Recommended).

### Guide visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Always visible (Recommended) | Subdued cube/guide consistently available; no extra toggle | ✓ |
| One Guides toggle | One labelled toggle for both, initially visible | |
| You decide | Readable without unnecessary controls | |

**User's choice:** Always visible (Recommended).

**Continuation question:** More orientation questions, or move on? Remaining slice/tracer areas were listed.
**Options:** Next area (save and discuss slices); More questions (refine cues).
**User's choice:** Next area.

## Slice selection and depth

### Plane/depth controls

| Option | Description | Selected |
|--------|-------------|----------|
| Buttons + % slider (Recommended) | Native XY/XZ/YZ segments, continuous depth and axis-labelled %; no grid indices | ✓ |
| Menu + % slider | Compact plane pop-up with same labelled slider | |
| You decide | Clear native controls, keyboard access, depth-axis labels | |

**User's choice:** Buttons + % slider (Recommended).

### Depth when switching planes

| Option | Description | Selected |
|--------|-------------|----------|
| Keep same % (Recommended) | Shared percentage: XY 30% through Z becomes XZ 30% through Y | ✓ |
| Remember per plane | Independent depths initially 50%; restore on return | |
| Always centre on switch | Each plane change resets to 50% | |

**User's choice:** Keep same % (Recommended).

### Camera when switching planes

| Option | Description | Selected |
|--------|-------------|----------|
| Keep camera (Recommended) | Change only plane; possible edge-on view recoverable by orbit/reset | ✓ |
| Face selected plane | Rotate to face new plane while retaining depth | |
| You decide | Least disorienting behaviour after visual validation | |

**User's choice:** Keep camera (Recommended).

### Returning to centre depth

| Option | Description | Selected |
|--------|-------------|----------|
| Centre Slice button (Recommended) | Set depth to 50% only, retain plane/camera/tracers/simulation | ✓ |
| Slider only | Smaller panel; use slider and keyboard | |
| You decide | Decide whether shortcut earns panel space | |

**User's choice:** Centre Slice button (Recommended).

**Continuation question:** More slice questions, or move on? Remaining tracer area was listed.
**Options:** Next area (save and discuss tracers); More questions (refine slices).
**User's choice:** Next area.

## Tracer appearance and defaults

### Starting distribution

| Option | Description | Selected |
|--------|-------------|----------|
| Across volume (Recommended) | Sparse repeatable distribution reveals flow even outside dye | ✓ |
| Near dye blob | Follow motion around initial dye region | |
| You decide | Deterministic seeding reveals genuine 3D motion | |

**User's choice:** Across volume (Recommended).

### Initial visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Visible initially (Recommended) | Show motion aid immediately, with native Show Tracers checkbox | ✓ |
| Hidden initially | Dye/guides first; enable markers explicitly | |
| You decide | Clearest uncluttered default from visual validation | |

**User's choice:** Visible initially (Recommended).

### Appearance against amber dye

| Option | Description | Selected |
|--------|-------------|----------|
| Small cool dots (Recommended) | Sparse pale-cyan dots contrast with amber; no trails/arrows/speed scale | ✓ |
| Small neutral dots | White/light-grey, potentially blending into cream dye | |
| You decide | Colour/size/density chosen for unobtrusive contrast | |

**User's choice:** Small cool dots (Recommended).

### Markers behind the slice

| Option | Description | Selected |
|--------|-------------|----------|
| Depth-occluded (Recommended) | Opaque cut sheet hides covered markers behind it; orbit reveals them | ✓ |
| Dim through-plane markers | Explained X-ray aid with faint behind-plane markers | |
| You decide | Visually checked front/back policy; not equal-brightness always-on-top | |

**User's choice:** Depth-occluded (Recommended).

**Continuation question:** More tracer questions, or finish? No selected areas remained.
**Options:** Finish area (save and review); More questions (refine tracers).
**User's choice:** Finish area.

## Final review

Presented a summary of all four areas, inherited restart preservation/presentation independence, and remaining technical planning responsibilities.

**Question:** Ready to write Phase 8 context, or is another implementation choice unclear?
**Options:** I'm ready for context (write decisions/references); Explore more gray areas (identify further unresolved choices).
**User's choice:** I'm ready for context.

**Notes:** All answers were explicit option selections; no free-text amendments, user-supplied references or new feature requests arose. Recommendations were assistant suggestions explicitly selected by the user, not silent defaults. Incremental checkpoints were saved after each completed area. No empty-response fallback was needed.

## Agent's Discretion

No substantive selected preference was delegated through a You decide option. Exact camera parameters/projection, native keyboard camera affordances, panel layout, styling, marker count/size, deterministic tracer algorithm, sampling/boundary policy, rendering resources, Swift/Metal design and fixture tolerances remain research/planning work within the captured decisions. No implementation or visual/numerical acceptance was performed during discussion.

## Deferred Ideas

None added. Existing Phase 9/10 and out-of-scope boundaries remain in CONTEXT.md. Phase 7 manual acceptance and unavailable runtime/device checks are not converted to passes by this discussion.

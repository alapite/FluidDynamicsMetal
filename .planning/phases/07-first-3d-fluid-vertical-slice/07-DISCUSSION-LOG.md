# Phase 7: First 3D Fluid Vertical Slice - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-06
**Phase:** 07-first-3d-fluid-vertical-slice
**Areas discussed:** Selecting the 3D lesson; First fixed-slice appearance; Starting flow and dye; Minimal 3D control surface
**Execution:** Interactive discussion and inline codebase scouting; no independent-agent verification claimed.

## Area Selection

The user selected all four offered areas: lesson selection, fixed-slice appearance, starting flow and dye, and minimal controls. Prior milestone choices and approved requirements were carried forward rather than re-asked. No matching pending todos, existing context, SPEC.md, or interrupted checkpoint was present at entry.

## Selecting the 3D lesson

### Where should users find the 3D lesson?

| Option | Description | Selected |
|--------|-------------|----------|
| Existing list (recommended) | Add 3D Dye Advection beside current entries with minimal navigation change. | |
| Grouped experiment list | One selector with explicit 2D and 3D group headings. | ✓ |
| Separate 2D/3D selector | Choose dimension first, then lesson; adds another navigation control. | |

**User's choice:** Grouped experiment list.

### Where should its identity stay visible?

| Option | Description | Selected |
|--------|-------------|----------|
| Panel heading (recommended) | 3D Dye Advection plus a fixed-slice descriptor; uncluttered canvas. | ✓ |
| Panel and canvas label | Also show a persistent 3D · fixed slice label when the panel is hidden. | |
| Selected list entry only | No additional persistent heading or canvas label. | |

**User's choice:** Panel heading.

### How should the grouped list name the existing 2D choices?

| Option | Description | Selected |
|--------|-------------|----------|
| Keep names (recommended) | Group headings distinguish dimensions; existing titles unchanged; new entry 3D Dye Advection. | ✓ |
| Dimension in every title | Add dimension prefixes as well as group headings. | |
| Match descriptive wording | Name the new entry Dye carried by a 3D flow. | |

**User's choice:** Keep names.

### How should the Mac menu expose the grouped navigation?

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror groups (recommended) | Same grouping and selected lesson as the panel; no new shortcut required. | ✓ |
| 3D submenu | Keep the existing flat 2D menu and add a 3D submenu. | |
| You decide | Simplest consistent native menu arrangement. | |

**User's choice:** Mirror groups.

**Area gate:** Offered Next area / More questions; user chose **Next area**. Checkpoint saved.

## First fixed-slice appearance

### What framing should the first cross-section use?

| Option | Description | Selected |
|--------|-------------|----------|
| Face-on square (recommended) | Fixed central XY slice, straight on, square fit like existing lessons. | ✓ |
| Angled plane in a box | Static angled slice in a wireframe cube, without camera interaction. | |
| You decide | Simplest readable fixed view with explicit slice location. | |

**User's choice:** Face-on square.

### How should dye concentration look?

| Option | Description | Selected |
|--------|-------------|----------|
| Blue on black (recommended) | Familiar black/blue/pale-cyan dye palette. | |
| Distinct 3D palette | Separate concentration ramp distinguishes 3D. | ✓ |
| You decide | Readable concentration palette without implying different substances. | |

**User's choice:** Distinct 3D palette. A follow-up resolved the actual palette.

### Which distinct palette?

| Option | Description | Selected |
|--------|-------------|----------|
| Warm amber (recommended) | Black through orange/amber to pale cream. | ✓ |
| Violet to pink | Black through violet to pale pink. | |
| Teal to mint | Black through green-teal to pale mint, closer to existing cyan. | |

**User's choice:** Warm amber.

### How much orientation information should accompany the slice?

| Option | Description | Selected |
|--------|-------------|----------|
| Panel descriptor (recommended) | XY slice · halfway through Z and a concentration legend; no canvas axes/grid. | ✓ |
| Small edge axis labels | X/Y at slice edges, fixed depth in panel. | |
| Border and axis arrows | Outlined square and small X/Y arrows; depth/legend in panel. | |

**User's choice:** Panel descriptor.

**Area gate:** Offered Next area / More questions; user chose **Next area**. Checkpoint updated.

## Starting flow and dye

### What should the initial flow feel like?

| Option | Description | Selected |
|--------|-------------|----------|
| Rolling circulation (recommended) | Smooth contained tumbling flow across and through the slice. | ✓ |
| Twisting swirl | Gently twisting depth-varying circulation and winding paths. | |
| You decide | Clearest deterministic nonplanar flow supporting later speed comparisons. | |

**User's choice:** Rolling circulation.

### What should the initial dye arrangement be?

| Option | Description | Selected |
|--------|-------------|----------|
| One soft patch (recommended) | One smooth compact 3D blob, off centre, intersecting the slice at step 0. | ✓ |
| Two separated patches | Two same-colour landmarks, more complex comparison. | |
| Short thick stripe | Finite 3D band; resembles the existing stretching lesson. | |

**User's choice:** One soft patch.

### What matters as dye leaves the fixed plane?

| Option | Description | Selected |
|--------|-------------|----------|
| Readable early motion (recommended) | Visible initial patch and early transport, honest thinning/disappearance, short explanation. | ✓ |
| Frequent exit and return | Emphasise disappearance/return as the depth cue even if harder to follow. | |
| You decide | Evidence-based observation window; no dye replenishment or moving plane to fake continuity. | |

**User's choice:** Readable early motion.

### Should the experiment deliberately fade dye?

| Option | Description | Selected |
|--------|-------------|----------|
| No added fading (recommended) | No explicit decay; transport and numerical smoothing can still change the image. | ✓ |
| Gentle fading | Deliberate explained decay, distinct from leaving the section. | |
| You decide | Clearest teaching default, documenting any explicit decay. | |

**User's choice:** No added fading.

**Area gate:** Offered Next area / More questions; user chose **Next area**. Checkpoint updated.

## Minimal 3D control surface

### What happens to unsupported 2D fields, overlays and tuning?

| Option | Description | Selected |
|--------|-------------|----------|
| Hide them (recommended) | Only supported controls in 3D; normal controls restored in 2D. | ✓ |
| Disable with explanation | Keep unavailable sections visible with a dye-only note. | |
| Hide tuning, disable views | Remove tuning but retain unavailable view/overlay sections. | |

**User's choice:** Hide them.

### What does S do in dye-only 3D?

| Option | Description | Selected |
|--------|-------------|----------|
| No action (recommended) | No field/state change; Space keeps Run/Pause with native focus respected. | ✓ |
| Brief availability hint | No state change, but panel hints that only dye is available. | |
| You decide | Least surprising supported behaviour; preserve the 2D shortcut. | |

**User's choice:** No action.

### How much Phase 7 explanation appears in the panel?

| Option | Description | Selected |
|--------|-------------|----------|
| Short factual note (recommended) | 3D cross-section, concentration, dye leaving plane, steps not seconds; no prediction/speed comparison yet. | ✓ |
| Bare essentials | Only title, descriptor, legend and count. | |
| Collapsible details | Minimal visible panel, explanation in About disclosure. | |

**User's choice:** Short factual note.

### What if 3D GPU-resource initialisation fails?

| Option | Description | Selected |
|--------|-------------|----------|
| Explain and keep 2D (recommended) | Native error and usable retained/restored 2D; no fake 3D or unexplained blank canvas. | ✓ |
| 3D unavailable panel | Stay selected in 3D, disable transport and display failure. | |
| You decide | Clear native failure, usable 2D, no false success. | |

**User's choice:** Explain and keep 2D.

**Area gate:** Offered Finish area / More questions; user chose **Finish area**. Checkpoint updated.

## Final Confirmation

Presented a summary of all four areas and offered **I'm ready for context** / **Explore more gray areas**. The user chose **I'm ready for context**, approving creation of the context and discussion log.

## Agent's Discretion

The user did not select You decide on any question. Technical numerical design, exact visual values and copy, native grouping mechanics, safe fallback implementation and component wiring remain researcher/planner responsibilities within the chosen behaviour. These are not additional user-approved numerical-method choices.

## Deferred Ideas

None arose. Camera/movable slices/tracers, complete comparative lesson/repeatability, volume rendering, mobile 3D and broader inspection remain assigned or deferred by the existing roadmap and requirements.

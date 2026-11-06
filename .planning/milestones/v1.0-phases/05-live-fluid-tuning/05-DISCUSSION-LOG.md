# Phase 5: Live fluid tuning - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `05-CONTEXT.md`; this log preserves alternatives considered.

**Date:** 2026-09-25
**Phase:** 5-live-fluid-tuning
**Areas discussed:** Tuning controls placement, Force and dye feel, Swirl and fade feel, Values and feedback

---

## Tuning controls placement

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| How should people open the four controls? | **Expand existing HUD** — one familiar entry point; separate floating panel — second on-canvas surface; always visible together — more canvas covered; you decide — planner chooses. | Expand existing HUD |
| Fresh-launch section state? | **Closed** — compact familiar controls; open — sliders visible immediately; platform-specific — open Mac/closed iOS; you decide. | Closed |
| While dragging canvas after opening? | **Stay open** — easy experiment-and-adjust; close on canvas drag — clear view automatically; you decide. | Stay open until manually closed |
| Narrow iPhone / small Mac layout? | **Scroll within HUD** — preserve corner and limit height; temporarily swap content — tuning replaces field buttons; move HUD for space — reposition it; you decide. | Scroll within HUD |

**Notes:** Existing Phase 4 HUD anchors and canvas interaction outside the HUD remain in force.

---

## Force and dye feel

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| When does a change during a drag take effect? | **Next movement** — ongoing stroke changes immediately; next stroke only — original strength until lift; you decide. | Next movement |
| Force zero, Dye nonzero? | **Dye without stirring** — deposit dye into possible existing flow; disable whole stroke — nothing; you decide. | Dye without stirring |
| Dye zero, Force nonzero? | **Stir without dye** — move existing fluid without new dye; disable whole stroke — nothing; you decide. | Stir without dye |
| Alter fluid already on canvas? | **Future input only** — existing fluid unchanged; reinterpret existing fluid — change existing color/motion; you decide. | Future input only |

**Notes:** Inputs are independent; changing one must not silently zero the other.

---

## Swirl and fade feel

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| Swirl changes existing circulation? | **Yes, ongoing flow** — new strength on next running frames; only future strokes — existing flow unchanged; you decide. | Yes, ongoing flow |
| Fade changes currently visible dye? | **Yes, current dye** — next running frames use new fade for all dye; only new dye — leave existing dye at prior rate; you decide. | Yes, current dye |
| Swirl zero and stirring? | **Yes, no added swirl** — motion still works; freeze motion — master motion control; you decide. | Motion still works |
| Fade dye only or motion too? | **Dye and motion together** — preserve shared decay; dye only — velocity decay unchanged; you decide. | Dye and motion together |

**Notes:** No solver step should occur just because a slider moves while paused.

---

## Values and feedback

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| Control type? | **Four sliders** — continuous live adjustment; steppers — discrete increments; you decide. | Four sliders |
| What values appear next to sliders? | **Percent of range** — approachable 0–100%; raw values — shader constants; no numbers — thumb only; you decide. | Percent of user-facing range |
| Higher Fade value means? | **Faster fade** — dye/motion disappear sooner; longer persistence — relabel Persistence; you decide. | Faster fade |
| Fade range around default? | **Usable range around default** — travel in both directions; full raw range — default near an end; you decide. | Usable range around default |

**Notes:** The existing raw retention default is 0.998, opposite the desired increasing-Fade direction. Preserve the default look without mapping displayed percentages directly to the full raw retention interval.

---

## Agent's Discretion

No explicit "you decide" answers. Native styling, practical slider mappings/bounds within shared state, and layout mechanics remain implementation details for research and planning.

## Deferred Ideas

None arose during this discussion. The existing roadmap reserves quality/resolution and visible reset for Phase 6.

# Phase 3: Reliable simulation state - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `03-CONTEXT.md`; this log preserves the alternatives considered.

**Date:** 2026-09-24
**Phase:** 3-reliable-simulation-state
**Areas discussed:** Fluid across resize, Paused display and input, App background return, State-check expectations

---

## Fluid across resize

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| Existing fluid after resize/rotation? | Preserve fluid (keep pattern and adapt it); Fresh canvas (clear and keep interaction working); You decide | Preserve fluid |
| Major aspect-ratio change? | Fit to canvas (stretch/reproject full pattern); Keep proportions (crop or empty edges); You decide | Fit to canvas |
| Drag across live resize/rotation? | Resume seamlessly (new size, no stranded forces); Release then restart (fresh drag); You decide | Resume seamlessly |
| Resize while paused? | Yes (keep paused fluid visible in new shape); Resume on resize; You decide | Yes |

**Notes:** Chose to move on after these four decisions.

---

## Paused display and input

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| Switch field while paused? | Show field now (no simulation advance); Show on resume; You decide | Show field now |
| Drag while paused? | Ignore input; Queue strokes; Allow painting without motion | Ignore input |
| Drag starts paused, held through resume? | Start from current point (no large impulse); Require new drag; You decide | Start from current point |
| Field on resume? | Keep selected; Return to density; You decide | Keep selected |

**Notes:** Existing shortcuts remain as chosen in Phase 2. Chose to move on after these four decisions.

---

## App background return

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| Pause state on iOS foreground return? | Restore choice (resume only if previously running); Always resume; Always paused | Restore choice |
| Fluid and field after brief background trip? | Preserve both; Reset fluid only; You decide | Preserve both |
| Interrupted touch on inactivity? | Clear stale touches; Continue held touch; You decide | Clear stale touches |
| Background elapsed time? | Freeze elapsed time; Catch up; You decide | Freeze elapsed time |

**Notes:** Chose to move on after these four decisions.

---

## State-check expectations

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| Field-selection checks? | All four fields (density default, complete cycle); Default and one switch; You decide | All four fields |
| Pause checks? | Full transition cycle (running, pause, switch, resume, selection kept); Pause toggle only; You decide | Full transition cycle |
| Future tuning-state checks now? | Defaults and bounds (include outside-limit behavior, no control UI); Full reset model; You decide | Defaults and bounds |
| Explicit VER-01 reset coverage? | Yes, state reset (change values, restore defaults, no UI); Defer reset check to Phase 6 | Yes, state reset |

**Notes:** The final question clarified that VER-01 requires reset behavior in Phase 3 even though the visible reset control belongs to Phase 6. The user chose to write context after these four areas.

## Agent's Discretion

No “you decide” choices were selected. Technical design, framework, state representation, and numeric limits remain for research and planning.

## Deferred Ideas

None raised during this discussion.

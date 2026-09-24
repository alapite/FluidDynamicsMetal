# Phase 2: Modern iOS parity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` — this log preserves alternatives considered.

**Date:** 2026-09-24
**Phase:** 2-modern-ios-parity
**Areas discussed:** Touch stirring, Existing gestures, Visual parity, Device sign-off

---

## Touch stirring

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| How should simultaneous fingers stir? | All fingers (each adds density); One finger only (first finger); You decide | All fingers |
| What if one stirring finger lifts? | Others continue (only lifted finger stops); Stop all stirring (must re-touch); You decide | Others continue |
| Does a stationary touch add dye? | On touch-down (matches Mac); Only while dragging; You decide | On touch-down |
| How should a cancelled touch respond? | End that touch (others continue, no stuck input); Clear all touches; You decide | End that touch |

**Notes:** Multi-finger input should remain continuous through individual lift/cancellation. A tap-only delay to recognize double-taps was accepted in the gestures discussion.

---

## Existing gestures

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| Keep iOS one-finger double-tap pause and two-finger double-tap field cycle? | Keep both (existing shortcuts); Change shortcuts; You decide | Keep both |
| Should shortcut double-taps deposit dye? | No visible dye (controls only); Taps also add dye; You decide | No visible dye |
| If clean double-taps require delayed tap-only dye, which takes priority? | Clean shortcuts (slight tap delay, prompt drag); Instant dye (possible double-tap mark); You decide | Clean shortcuts |
| Keep Mac Space-to-pause and S-to-cycle? | Keep both (Phase 1 baseline); Adjust keys; You decide | Keep both |

**Notes:** Immediate touch-down dye and clean double-tap shortcuts can conflict; clean shortcuts win when necessary, but dragging stays prompt.

---

## Visual parity

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| Default iOS look? | Match blue-on-black (density default); Platform-specific look; You decide | Match blue-on-black |
| Stroke footprint on iPhone vs iPad? | Similar relative size (comparable canvas proportion); Same pixel radius; You decide | Similar relative size |
| How strict is Mac/iOS visual matching? | Recognizable feel (color, swirl, fade); Near-identical frame; You decide | Recognizable feel |
| Should fluid continue filling the screen? | Full canvas (unobstructed); Visible frame; You decide | Full canvas |

**Notes:** The Phase 1 Mac baseline and original animation in `README.md` provide the visual reference; exact screenshots need not match.

---

## Device sign-off

| Question | Options presented | User's choice |
|----------|-------------------|---------------|
| What establishes iOS 26 launch-and-drag parity? | Physical device; Simulator sufficient (emulated touch); You decide | Simulator sufficient |
| Cover both iPhone and iPad simulator layouts? | Both; One form factor; You decide | Both |
| How to check the Mac side? | Build plus existing reference (defer macOS 26 runtime); Repeat Mac interaction on available host; You decide | Build plus existing reference |
| What if Simulator cannot demonstrate real multi-touch? | Mark unverified (device-only); Require device; You decide | Mark unverified |

**Notes:** Simulator verification is sufficient for this phase, but physical multi-finger input must not be reported as tested. Phase 1 macOS 26 runtime UAT remains deferred to milestone closeout.

---

## Agent's Discretion

No user-facing choice was delegated; implementation details remain with research and planning.

## Deferred Ideas

None raised during discussion.

---
status: partial
blocking: false
phase: 02-modern-ios-parity
source: [02-VERIFICATION.md, 02-PARITY.md]
started: 2026-09-24
updated: 2026-09-24
---

# Phase 2 — Follow-up interaction checks

The user approved Phase 2 sign-off with the following explicitly unobserved cases deferred. **These do not block implementation of the rest of the milestone.** Two-finger gestures cannot be tested with the available simulator; do not treat them as passed or require repeated simulator attempts. See `02-PARITY.md` for simulator checks that passed. A simulator check is not a physical-device pass.

## Current Test

Deferred manual checks; continue with Phase 3 and later phases. Revisit two-finger gestures and concurrent contacts when a physical iOS device is available.

## Tests

### 1. Two-finger double tap and dye-free field cycling
expected: On an iOS 26 iPhone and iPad, a two-finger double tap cycles density → pressure → velocity → vorticity → density exactly once per shortcut without adding dye or pausing.
result: deferred — NOT TESTED, device-only; the simulator cannot exercise this two-finger gesture. Non-blocking for milestone implementation.

### 2. Independent simultaneous contacts and one-touch lift/cancel
expected: Every concurrent touch adds independent force/density; lifting or cancelling one leaves other fingers active without stale or oversized splats, including more than five touches if supported by the device.
result: deferred — NOT TESTED, device-only; physical-device check pending, non-blocking for milestone implementation.

### 3. Phone/tablet stroke proportions
expected: A stroke affects a comparable fraction of the shorter canvas side on iPhone and iPad at default settings.
result: deferred — NOT TESTED; no explicit side-by-side fractional-width comparison was reported. Non-blocking for milestone implementation.

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

No observed failures. These are unverified behaviors, not code defects or blockers for later phases.

---
status: partial
phase: 02-modern-ios-parity
source: [02-VERIFICATION.md, 02-PARITY.md]
started: 2026-09-24
updated: 2026-09-24
---

# Phase 2 — Follow-up interaction checks

The user approved Phase 2 sign-off with the following explicitly unobserved cases pending. See `02-PARITY.md` for simulator checks that passed. A simulator check is not a physical-device pass.

## Current Test

Awaiting follow-up testing when a reliable two-finger simulator gesture or physical iOS device is available.

## Tests

### 1. Two-finger double tap and dye-free field cycling
expected: On an iOS 26 iPhone and iPad, a two-finger double tap cycles density → pressure → velocity → vorticity → density exactly once per shortcut without adding dye or pausing.
result: pending — not performed during Phase 2 simulator sign-off.

### 2. Independent simultaneous contacts and one-touch lift/cancel
expected: Every concurrent touch adds independent force/density; lifting or cancelling one leaves other fingers active without stale or oversized splats, including more than five touches if supported by the device.
result: pending — simulator multi-touch was not established as convincing; physical-device check pending.

### 3. Phone/tablet stroke proportions
expected: A stroke affects a comparable fraction of the shorter canvas side on iPhone and iPad at default settings.
result: pending — no explicit side-by-side fractional-width comparison was reported.

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

No observed failures. These are unverified behaviors, not code defects.

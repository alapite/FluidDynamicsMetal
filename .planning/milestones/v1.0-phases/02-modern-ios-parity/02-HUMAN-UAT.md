---
status: partial
blocking: false
phase: 02-modern-ios-parity
source: [02-VERIFICATION.md, 02-PARITY.md]
started: 2026-09-24
updated: 2026-09-25
---

# Phase 2 — Follow-up interaction checks

The user approved Phase 2 sign-off with the following explicitly unobserved cases deferred. **These do not block later phases or completion of the milestone.** Xcode 27 Device Hub does not currently offer two-finger tap/pan simulation via the old Option-key mechanism, as reported in the [Apple Developer Forums Device Hub discussion](https://developer.apple.com/forums/thread/846533). Do not treat simulator input as a physical-device pass or require repeated Device Hub attempts. Revisit if a physical device or capable tooling becomes available; see `02-PARITY.md` for simulator checks that passed.

## Current Test

Deferred manual checks; continue with Phase 3 and later phases. Revisit two-finger gestures and concurrent contacts when a physical iOS device is available.

## Tests

### 1. Two-finger double tap and dye-free field cycling
expected: On an iOS 26 iPhone and iPad, a two-finger double tap cycles density → pressure → velocity → vorticity → density exactly once per shortcut without adding dye or pausing.
result: deferred — NOT TESTED, device-only with current Device Hub; non-blocking for later phases **and milestone completion**.

### 2. Independent simultaneous contacts and one-touch lift/cancel
expected: Every concurrent touch adds independent force/density; lifting or cancelling one leaves other fingers active without stale or oversized splats, including more than five touches if supported by the device.
result: deferred — NOT TESTED, device-only; physical-device check pending, non-blocking for later phases **and milestone completion**.

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

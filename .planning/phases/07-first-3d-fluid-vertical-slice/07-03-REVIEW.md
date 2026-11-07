---
phase: 07-first-3d-fluid-vertical-slice
plan: 03
status: clean
review_type: general-agent-read-only-static-review
date: 2026-11-07
---

# 07-03 Code Review

Two read-only passes were performed by a separate general-purpose review agent.
This was not typed GSD verification and did not run builds or tests. Runtime
acceptance must come from the actual production fixture and regression outputs.

## Findings and Resolution

| Finding | Severity | Resolution checked in second pass |
|---|---|---|
| Returned velocity divergence was not independently gated | High | Double readback computes all-cell divergence, true residual, both unchanged `1e-5` gates and the conditional `1000x` reduction. User-approved precision amendment retains strict ideal-Double identity and separately verifies facewise Float32 rounding plus the derived six-face identity budget. |
| Volume kernels read status while one thread could write failure status | Medium | Separate single-thread scalar validation/preparation passes precede field kernels; volume kernels consume const status and do not write it. Static regression enforces that boundary. |
| Finite-state snapshots omitted reduction/status buffers | Medium | Entire reduction workspace is staged/read/scanned; all status lanes are checked at reset and steps 1/72/600, alongside both texture generations. |
| Padded PCG iterations overwrote final genuine trace record | Medium | Encoded iteration index must match completed update count before capture. Fixture asserts the final true-residual-check record survives padding. |

## Other Checked Paths

- Negative and NaN search-denominator injections require explicit failure and
  non-convergence; zero denominator, incompatible RHS, NaN input and cap cases
  remain covered.
- The GPU harness refuses a production metallib older than `Shaders3D.metal`.
- No concrete generation-aliasing defect was found in the three-queued-command
  failure restore/copy path, assuming the documented single-queue submit order.

## Verdict

Second pass: **no unresolved findings from this review**. This does not mark the
phase complete, validate human visual acceptance, or substitute for fresh tests.

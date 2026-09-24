# Research Summary

**Date:** 2026-09-24

## Recommendation

Modernize the existing two-target Metal app incrementally. First make both schemes work with the new SDKs and compatibility targets; preserve the fluid's appearance while separating tunable state from the render loop; then use native, accessible controls around `MTKView` on each platform. Do not equate modernization with rewriting the solver.

## Table stakes

- Working macOS 26 / Apple Silicon and iOS 26 builds and runtime interaction.
- Discoverable pause, display-field selection, and adjustable simulation parameters on both platforms.
- Repeatable verification of configuration/state and manual GPU interaction parity.

## Risks to plan around

- Old Swift 4 syntax, deployment targets, and missing Metal Toolchain can mask true source-level errors.
- Swift `StaticData` / Metal `BufferData` layout and string-based function names are untyped cross-language contracts.
- UI bridges must retain renderer lifetime, update settings safely during timed drawing, and preserve platform-specific input coordinates.

## Source documents

- `.planning/research/STACK.md` — toolchain and framework options with Apple documentation links.
- `.planning/research/FEATURES.md` — requested table stakes and deferred extras.
- `.planning/research/ARCHITECTURE.md` — integration boundaries and build order.
- `.planning/research/PITFALLS.md` — concrete migration failure modes and mitigations.

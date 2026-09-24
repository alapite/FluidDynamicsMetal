# Architecture Research

**Date:** 2026-09-24

## Proposed boundaries

- Keep `Shared/Renderer.swift` as the rendering entrypoint and `Shared/Shaders.metal` as the shader library. Extract a small, typed configuration/display-state interface so both platform UIs can update one simulation without duplicating Metal code.
- Give macOS and iOS separate input adapters; their existing `RenderViewController.swift` files demonstrate distinct mouse and touch coordinate paths. If choosing SwiftUI controls, bridge `MTKView` into each UI using [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable.md) and [UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable.md).
- Keep drawable acquisition near the display pass rather than holding a drawable across simulation steps, consistent with [MTKView guidance](https://developer.apple.com/documentation/metalkit/mtkview.md).

## Data flow

1. User changes a control or interacts with the fluid canvas.
2. Platform UI validates input and updates shared configuration / forwards pointer or touch positions.
3. `Renderer.draw(in:)` snapshots settings for a frame and writes uniforms to a free buffer before scheduling GPU passes.
4. `Slab` ping/pong textures receive passes from shader functions; the selected field is rendered to the drawable.

## Suggested build order

1. Stabilize builds on the new targets/toolchain and record a visual/interaction baseline.
2. Create a typed, testable simulation state/configuration boundary and safe renderer updates, preserving shader contracts.
3. Wrap the `MTKView` in native platform UI, then expose a small set of tunable parameters and field controls.
4. Verify parity on both platforms and document current controls and build commands.

## Alternatives considered

- Keep storyboard/AppKit/UIKit and add controls directly: smaller migration, but more duplicated UI wiring; reasonable fallback if SwiftUI bridging disrupts pointer/touch handling.
- Rewrite simulation in compute shaders: high migration cost and greater parity risk without a demonstrated need.

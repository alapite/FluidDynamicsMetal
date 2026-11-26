# Visual presentation release verification

Verification on 26 November 2026 covered the revised 2D lesson rendering, the paused starting outline, and the Free Play preview and experiment chooser. The full suites ran on `e10a59d` on `feature/lesson-visual-presentation`. A focused simulator run covers the subsequent mobile transport layout adjustment. [Final simulator result](../.build/visual-presentation-release/ios-final.xcresult)

## Environment

| Surface | Environment |
|---|---|
| Mac and Metal | Apple M3 Pro MacBook Pro, macOS 27.2.1 (26B131), Xcode 27.2 (27B52), arm64 Debug |
| iPhone | iPhone 17 Pro simulator, iOS 26.4, Debug |
| iPad | iPad Pro 13-inch (M5) simulator, iPadOS 26.4, Debug |

## Automated results

- Both app schemes built successfully with code signing disabled.
- All 58 Mac cases passed across the full run and targeted retries. The full run passed 55 cases, including all 29 state and contact tests. The remaining HUD cases passed after clicking the native checkbox, choosing a canvas point outside the floating panel, waiting for the 3D recovery dialog to close, and resizing from the straight window edge. [Full run](../.build/visual-presentation-release/mac.xcresult) · [HUD retry](../.build/visual-presentation-release/mac-retest.xcresult) · [Outline resize retry](../.build/visual-presentation-release/mac-outline.xcresult)
- Integration discovery passed all 50 tests, including the educational Metal harness, the production 3D GPU fixtures, and the independent CPU reference tests. The 2D GPU comparisons used the existing relative tolerance of `1e-3` and absolute tolerance of `1e-4`.
- The full simulator suite passed all 14 cases on iPad and 11 of 14 on iPhone. The three iPhone checks passed after waiting for a committed menu selection, scrolling the fade slider fully into view, and scrolling the native menu at the largest text size. [Full simulator run](../.build/visual-presentation-release/ios.xcresult) · [iPhone retry](../.build/visual-presentation-release/iphone-retest.xcresult)
- The recorded iPhone first-drag test verified that dye appeared at the original contact after that drag dismissed the launch preview. [XCTest result](../.build/visual-presentation-release/first-drag.xcresult)

## Visual evidence

The advection pair shows normal flow at step 240 on the same 640 × 640 pixel canvas. The revised view makes the dye patch stand out and leaves the direction of motion readable through the fading trails. [Before still](../.build/visual-presentation/before/advection-step-240.png) · [After still](../.build/visual-presentation/after/advection-step-240.png) · [Before animation](../.build/visual-presentation/before/advection-running.gif) · [After animation](../.build/visual-presentation/after/advection-running.gif)

The dashed starting shapes remain distinct from the evolved dye in both paused comparisons. The GPU test measured the changed pixels against the seeded contour in a letterboxed viewport and verified that drawing the outline left the fields and accepted-step count identical. [Advection outline](../.build/educational-evidence/starting-outline-0-step-240.png) · [Stretching outline](../.build/educational-evidence/starting-outline-2-step-240.png)

The Mac window narrowed from 993 to 717 points while paused. The captured contour stayed centered on the starting stripe and the HUD retained the same step count and outline setting. [Before resizing](../.build/visual-presentation-release/mac-outline-before-resize.png) · [After resizing](../.build/visual-presentation-release/mac-outline-after-resize.png)

The native menus keep the titles and selection marks legible beside the full-color thumbnails. Mac also shows the 3D group. [Mac chooser](../.build/visual-presentation-release/mac-chooser.png) · [iPhone chooser](../.build/visual-presentation-release/iphone-chooser.png) · [iPad chooser](../.build/visual-presentation-release/ipad-chooser.png)

The iPhone and iPad lesson canvases remained square and clear of the controls in portrait and landscape. The largest Dynamic Type setting kept the pinned transport inside the panel. The final simulator check measures the visible mobile label **Restart** against the height of **Step** and checks that its accessibility label is **Restart experiment**. [iPhone portrait](../.build/visual-presentation-release/iphone-advection-portrait.png) · [iPhone landscape](../.build/visual-presentation-release/iphone-advection-landscape.png) · [iPhone largest text](../.build/visual-presentation-release/iphone-large-text-landscape.png) · [iPad largest text](../.build/visual-presentation-release/ipad-large-text-landscape.png)

The eight-second iPhone recording starts at launch, shows the preview disappear on contact, and follows the live dye from the starting point through the drag. [First drag MP4](../.build/visual-presentation-release/first-drag.mp4)

## Checks requiring other hardware or a runtime

- macOS 26 runtime behavior remains unverified. The Mac checks ran on macOS 27.2.1.
- Physical iPhone and iPad gestures, including concurrent touches and the two-finger shortcut, remain unverified. The iOS checks used simulators.

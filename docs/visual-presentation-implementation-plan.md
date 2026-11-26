# Make the fluid easier to see, follow, and explore

Implement four coordinated changes for Mac, iPhone, and iPad. Give each 2D lesson a distinct visual emphasis, demonstrate a stirring gesture when Free Play opens, illustrate the experiment chooser with actual simulation frames, and let learners compare paused dye against its starting shape. Use the existing native controls and Metal renderer. The solver, experiment recipes, step counts, and saved Free Play preferences retain their current behavior.

Deliver the **advection comparison at step 240 first**. The existing educational capture harness explicitly enables overlays in some captures, so those images are useful stress tests but do not establish what a user sees by default. Capture the current production defaults before making changes. Use that baseline for the visual review.

## 1. Shared rendering and lesson defaults

**Owner: rendering and simulation-state agent.** Own the shared 2D display code, lesson presentation settings, and corresponding state and Metal tests.

| Lesson | Opening field | Initial overlays | What should stand out |
|---|---|---|---|
| Dye carried by a flow | Dye concentration | Particles and trails on, arrows off | The dye patch and its direction of travel |
| Two interacting vortices | Vorticity | Sparse arrows on, particles and trails off | The two rotating cores and their direction |
| Stretching dye by stirring | Dye concentration | All overlays off | The changing outline and folds of the stripe |

- Replace the single `DisplayOptions.lesson` preset with defaults keyed by `ExperimentID`. Apply them on lesson selection. Restart and adjustment changes preserve the user’s field and overlay choices. Preserve the existing velocity-field behavior that shows direction arrows and the existing dependency between particles and trails.
- In the 2D density shader, change the palette coordinate from `c / (1 + c)` to `sqrt(c / (1 + c))`, with `c` clamped to zero at the lower bound. Apply it consistently to Free Play and lessons. Keep the black, blue, and pale-cyan palette stops. Add “Brightness uses a square-root scale to reveal faint dye” to the density legend detail. Verify zero stays black and increasing concentration gives monotonically increasing brightness.
- In advection, draw 16 of the existing 256 tracers. Use rows and columns `1, 5, 9, 13` of the existing 16-by-16 seed lattice. Draw the same IDs for markers and their histories. Keep all 256 particles advancing so toggling overlays has no effect on evolution. Use a small marker head and a tail that fades from 35% opacity at its newest segment to zero at its oldest. Test the direction at a phone-sized viewport.
- In the vortex lesson, space arrows approximately 64 logical points apart, capped at eight rows and eight columns. Retain the existing zero-speed suppression and contrasting outline so both orange and blue regions remain readable. Other modes retain their existing arrow spacing and particle counts.
- Expose one shared way to resolve and draw the effective 2D presentation from mode, field, and display options. Use it in both `Renderer` and the educational capture harness. Keep the harness’s explicit all-overlay stress captures as separate, clearly named cases.

**First review artifact:** render the current and revised default advection views at normal speed, step 240, at identical scale. Include a paused still and a short running capture. At phone size, the dye patch should be the first identifiable feature. The fading tails should make its local direction legible without turning arrows on.

## 2. Paused comparison with the starting shape

**Owner: comparison-overlay agent.** Build the shared geometry, visibility rules, rendering pass, and focused tests. Give the platform agent a state query and a setter for the control.

- Add a native checkbox or switch labeled **Show starting outline**, with accessibility identifier `overlay.startingOutline`. Offer it in the advection and stretching lessons when the selected field is Dye concentration. Enable it while paused after at least one accepted step, including at completion. Default it to off on lesson selection. Retain its setting across stepping, resume/pause, field switches, restart, and adjustment changes within that lesson. At step zero and while running, suppress the outline.
- Derive the contour from the recipe’s **step-zero dye at concentration 0.5**. Build line segments once from the seeded grid using marching squares with linear edge interpolation. Use the same top-left normalized coordinates and cell centers as `ExperimentRecipes`. This gives the Gaussian patch and the softened stripe the same definition of “starting outline” and follows future recipe edits automatically.
- Draw a dashed neutral outline one logical point wide, with a subdued dark under-stroke so it remains visible over bright dye. Clip it to the existing simulation viewport and draw it between the field and the particle overlays. Redraw immediately on toggle and resize, including at lesson completion. The comparison requires no solver step or GPU-to-CPU readback.
- Test the advection contour against the Gaussian half-maximum radius and the stripe against its seeded half-maximum bounds. Include a letterboxed viewport, restart to step zero, single-step with the outline enabled, and resume/pause. Toggling the control must leave the step count and fluid fields identical.

## 3. Free Play opening gesture and illustrated chooser

**Owner: visual-assets agent** produces the assets and repeatable capture procedure. **Owner: platform integration agent** wires them into the existing AppKit and UIKit controllers and owns the platform UI tests. Use these conventions on both platforms.

**Free Play opening gesture**

- Produce one four-second, silent, square clip showing two curved dye strokes curling into a vortex. Capture it from the production 2D Free Play renderer using scripted contacts, default tuning, the revised density palette, and no overlays. Include a matching still from the final frame. Bundle both assets locally in both app targets.
- On fresh launch, display the clip once over the empty Free Play canvas, then hold the still. Display **Drag to stir** within the canvas safe area. Make the preview transparent to hit testing. With Reduce Motion enabled, show the still immediately. If playback fails, use the same still. Suspend playback while the app is inactive.
- Dismiss the preview on the first canvas pointer-down or touch-down and pass that same event through the normal input path. A tap must still deposit dye and a drag must begin at the original contact. Also dismiss on a simulation command, including field or overlay selection, pause, reset, or experiment selection, so the preview cannot obscure the result. Moving the Mac controls panel or scrolling the HUD does not dismiss it.
- Show the introduction once per app launch. Resetting Free Play or returning from a lesson produces the existing empty canvas. The clip never writes into live fluid, particle history, or counters. Expose the instruction as the existing accessible canvas’s hint. The decorative playback surface receives no accessibility focus.

**Experiment chooser**

- Keep the current Mac `NSPopUpButton` and iOS `UIMenu`. Add full-color square images to their existing items and preserve titles, selection marks, accessibility labels, grouping, and keyboard shortcuts. Keep the closed selector compact. On Mac, retain the existing text-only Simulation menu for keyboard navigation.
- Capture the advection patch at **normal speed, step 240**; the vortex pair at **opposite rotation, step 120**; and the stretched stripe at **normal stirring, step 240**. The opposite-rotation thumbnail illustrates the comparison available in the lesson; selecting it still opens the established same-rotation default. Use the opening-gesture still for Free Play. For the Mac-only 3D item, capture the production seeded view using its default slice and camera.
- Export square PNGs from the field viewport, omitting controls and legends. Crop around the visible subject with a 15% margin on each side, preserving aspect ratio. Supply a 96-pixel master for a nominal 32-point menu image and let the native menu apply its platform sizing. Decode and cache bundled images once. Verify each thumbnail at the actual menu size, particularly the narrow stripe.
- Use a shared asset catalog with membership in both app targets for 2D images, and the Mac catalog for the 3D image. Record the mode, adjustment, step, framing, and regeneration command alongside the capture tooling. Use separate output names for menu crops and full-frame regression evidence.

## 4. Integration order and release checks

1. **Baseline and prototype.** The rendering agent records current production-default captures, implements the revised advection view, and produces the step-240 comparison. Verify the formula, tracer selection, and direction cue before generating final artwork.
2. **Parallel work.** The rendering agent completes the vortex and stretching defaults. The comparison agent implements the contour and state contract. The visual-assets agent prepares scripted inputs and capture tooling. The platform agent owns both view controllers, Xcode target membership, menu integration, accessibility, and preview dismissal. Route shared-renderer integration through the rendering agent to avoid overlapping edits.
3. **Final assets and integration.** Generate the clip, still, and thumbnails from the integrated production renderer. Verify the chooser and the new outline control through the normal app entry points. Update the README’s launch behavior, per-lesson defaults, legend explanation, and manual checks.
4. **Automated verification.** Build both app schemes, run Mac state and HUD tests, run iOS HUD tests on available iPhone and iPad simulators, and run `python3 -m unittest discover -s Tests/Integration` against the rebuilt Mac app. Cover initial defaults, user overrides, reset/return behavior, preview dismissal on first input, Reduce Motion fallback, menu selection, and paused outline visibility. Preserve numerical regression tolerances and existing 3D checks.
5. **Visual acceptance.** Supply before/after captures at equal scale, the open chooser on both platforms, both paused comparisons, and a recording of the first drag from launch. Check iPhone portrait and landscape, iPad, and a resized Mac window. Verify the first stroke appears under the contact, the outline stays registered during resizing, and control text remains usable at enlarged text sizes. Record the host, simulator, and device used. Mark physical-device gestures and macOS 26 runtime behavior unverified wherever the required hardware or runtime is unavailable.

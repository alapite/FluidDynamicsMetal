---
status: diagnosed
trigger: "2d-lesson-switch-canvas-not-reset (UAT 07 test 5, gap G-07-5): switching directly between 2D modes changes the panel but not the canvas; via Free Play it works; 3D always works"
created: 2026-11-20T21:00:00Z
updated: 2026-11-20T21:20:00Z
---

## Current Focus

hypothesis: CONFIRMED. Paused 2D redraws (Renderer.redrawIfPaused -> drawPresentationOnly, and the paused Step drain -> draw(in:)) call the delegate method directly and fetch `view.currentDrawable` OUTSIDE MTKView.draw(). MTKView caches that drawable until the end of its next real draw(), so every paused redraw after the first renders into and re-presents the same already-presented drawable; the re-present never reaches the compositor.
test: done (see Evidence)
expecting: n/a
next_action: return ROOT CAUSE FOUND to caller (goal: find_root_cause_only; no source changes made)

bug_class: Bohrbug (deterministic; reproduced 3/3 runs with the real Renderer)
candidate_causes:
  - "code: presentation-only redraw path reuses MTKView's cached, already-presented drawable (CONFIRMED)"
  - "code/data: lesson reset or SimulationState transition leaves stale simulation state (ELIMINATED, see below)"
  - "environment: macOS 27 host / MTKView version difference (not needed: the behaviour is MTKView's documented drawable lifecycle; the same defect reproduces deterministically on this host)"
and_gate: "no - a single condition (paused 2D redraw outside MTKView.draw() when the cached drawable has already been presented) is sufficient; no second contributing condition required"

## Symptoms

expected: Switching to any 2D mode (Free Play or each of the three 2D lessons) shows that mode's fresh initial canvas state at Step 0, paused, with its usual controls.
actual: "What actually shows up depends on the order in which I select items. If I select Free Play first, then I can successfully initiate the other selections right afterwards, but switching directly between the other 2d choices doesn't really alter what's shown on the canvas (though it does change the control panel). Selecting 3D Dye Advection does successfully change the canvas state though, no matter what was selected previously."
errors: None reported
reproduction: Mac app; select one 2D lesson (Cmd-2), then directly another (Cmd-3/Cmd-4): panel changes, canvas keeps previous content. Via Free Play (Cmd-1) first works.
started: Discovered during UAT 2026-11-20.

## Eliminated

- hypothesis: SimulationState.selectMode/beginReset mishandles lesson->lesson transitions
  evidence: selectMode sets adjustment/tuning/field/displayOptions/userPaused and calls beginReset for every mode; Renderer.selectMode always calls replaceSimulation(reset: true) which builds a brand-new FluidSimulation and encodes the reset for the new mode/adjustment (command waitUntilCompleted, finishReset). Real-Renderer probe: the pixels the renderer encodes after each lesson selection are three different, repeatable images (checksums 8a69..., e6bd..., b073...) in every one of 8 consecutive lesson->lesson hops, so state/reset/render are correct.
  timestamp: 2026-11-20T21:20:00Z
- hypothesis: 3D frame pipelining (4097d80) or the 3D inspection redraw changes (f148b64) broke 2D switching
  evidence: those commits only touch 3D branches (requestInspectionRedraw/interactive3D); the 2D branch of redrawIfPaused is unchanged by them. The regression pre-dates them (b4b6be6).
  timestamp: 2026-11-20T21:20:00Z

## Evidence

- timestamp: 2026-11-20T21:00:00Z
  checked: Renderer.swift selectMode / replaceSimulation / redrawIfPaused / draw
  found: 2D selectMode -> replaceSimulation(reset:true) -> updateScheduling() (isPaused = true for lessons) -> redrawIfPaused() -> drawPresentationOnly(in:) -> draw(in:presentationOnly:true) which calls `view.currentDrawable`, renders and `command.present(drawable)`. It is invoked directly, not through MTKView.draw(). Nothing else in Sources/ calls view.draw()/setNeedsDisplay for 2D.
  implication: Presentation for a paused 2D mode depends on view.currentDrawable semantics outside MTKView's draw cycle.

- timestamp: 2026-11-20T21:05:00Z
  checked: git history of redrawIfPaused (git show 07703e2, 5baadb5, b4b6be6, f148b64)
  found: v1.0 (07703e2) through 5baadb5: `redrawIfPaused()` called `metalView?.draw()`. Commit b4b6be6 (08-03 "wire spatial renderer presentation") replaced it with `drawPresentationOnly(in: view)`. Commit f148b64 (2026-11-19) fixed the equivalent 3D symptom by routing 3D through `view.draw()` with the comment "MTKView retires its current drawable at the end of draw()", but left 2D on drawPresentationOnly.
  implication: Regression for paused 2D redraws introduced in 08-03, not by 4097d80 / f148b64 (those only fixed 3D).

- timestamp: 2026-11-20T21:10:00Z
  checked: standalone MTKView probe (scratchpad/drawable_experiment, drawable_visible, drawable_control), tiny visible window, presentedHandler/presentedTime used as display oracle
  found: outside view.draw(), consecutive `view.currentDrawable` accesses return the identical object (=== true) even after it was presented; only view.draw() retires it (new object afterwards). Presenting the cached drawable repeatedly: present #1 -> presentedHandler fired, presentedTime non-zero; presents #2 and #3 completed on the GPU but presentedHandler NEVER fired. Control mimicking the user's report: 5 real view.draw() frames (Free Play) -> outside-draw present "lesson A" DISPLAYED -> outside-draw present "lesson B" (same drawable object) NEVER presented, even after 1.5 s; later real view.draw() frames recover.
  implication: This is exactly "Free Play first works, then the next direct switch is not shown".

- timestamp: 2026-11-20T21:15:00Z
  checked: REAL Renderer (production sources) driven in a 160x160 visible window with an MTKView subclass logging every currentDrawable access (scratchpad/renderer_probe), 2 full runs plus a third with pixel readback
  found: Free Play (display link, 66 frames, 66 distinct drawables) -> Lesson 1 renders into a fresh drawable and is displayed; a trailing display-link draw() then retires it so Lesson 2 also gets a fresh drawable and is displayed; Lesson 3, three paused Steps, and all eight further direct lesson->lesson hops render into that same single drawable (#68), which had already been presented once, so none is presented. Lesson 1 selected after Free Play (control) again gets a fresh displayed drawable. Pixel readback shows each hop renders the correct, distinct lesson image into the stale drawable.
  implication: Reset/state/render are correct; only the presentation of paused 2D redraws fails. The first lesson after Free Play (or after a Run, 3D visit, or any real draw()) shows; subsequent direct hops do not. 3D always works because requestInspectionRedraw uses view.draw().

## Resolution

root_cause: Since 08-03 (b4b6be6), Renderer.redrawIfPaused() presents paused 2D frames by calling drawPresentationOnly(in:), i.e. the delegate draw routine directly, rather than MTKView.draw(). That routine takes `view.currentDrawable` outside a draw cycle. MTKView caches its current drawable until the end of its next real draw(), so after the first paused redraw every later paused redraw (lesson->lesson selection, restart, field/option change, resize, and the paused Step drain which also calls draw(in:) directly) renders correct pixels into the same already-presented drawable, and that second present never reaches the screen. Free Play (display-link draw()), a Run, or 3D selection (which uses view.draw()) retire the cached drawable, which is why those paths appear to work.
fix: (not applied - diagnose only) Route 2D paused redraws and the paused 2D Step drain through view.draw() when view.delegate === self, as already done for 3D.
verification: n/a (diagnose only)
files_changed: []

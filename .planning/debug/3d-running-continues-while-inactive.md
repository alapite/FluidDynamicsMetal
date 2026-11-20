---
status: diagnosed
trigger: "3d-running-continues-while-inactive (UAT 07 test 4, gap G-07-4): user reports that switching away (Cmd-Tab) or minimising does not seem to pause a running 3D Dye Advection lesson; manually-paused case passes"
created: 2026-11-20T21:30:00Z
updated: 2026-11-20T22:10:00Z
---

## Current Focus

hypothesis: CONCLUDED. The production code does NOT advance steps while inactive (objectively measured). The UAT "issue" is a false negative from (1) unobservable freeze (60 steps/s, 10.2 s lesson, counter lives only in a panel that hides on deactivate, no inactive indicator) and (2) Cmd-M being disabled whenever the Simulation Controls utility panel is the key window, so "minimise via Cmd-M" never minimises after the user has clicked Run in the panel.
test: done (see Evidence)
expecting: n/a
next_action: return ROOT CAUSE FOUND (diagnose only; no source changes, no commit)

bug_class: Bohrbug / specification-verification gap (no code defect reproduced in 60/60 randomized trials)
candidate_causes:
  - "code: running 3D frames still submitted after resignActive (in-flight completions, scheduleInspectionRedraw, scheduleStepDrain, display link) - ELIMINATED"
  - "code: observers not registered / fire for the wrong event (Cmd-Tab vs minimise) - ELIMINATED for minimise (real NSWindow.miniaturize observed); Cmd-Tab uses the documented willResignActive notification (real window-server activation NOT TESTED)"
  - "environment/UX: UAT cannot observe a freeze at 60 steps/s + hidden counter; Cmd-M disabled when utility panel is key - CONFIRMED as the explanation for the report"
  - "data: lesson auto-completes at 600 steps (user said 500) - confirms the run is only ~10 s long"
and_gate: "no for the code path (nothing advances); the report is explained by two independent UAT-side conditions that each independently make 'does it pause?' unanswerable, they are not both required"

## Symptoms

expected: While the 3D Dye Advection lesson is running, switching to another app (Cmd-Tab) or minimizing (Cmd-M) freezes evolution and the step counter; returning resumes without catch-up steps.
actual: User reported: "For part A, while it's hard to be sure due to the speed at which the steps increase (and the 500 step limit), it doesn't seem to me that switching away or minimising pauses execution. For part B, it's a full pass." (Part B = manually paused lesson stays paused and frozen across switch-away/minimize - passed.)
errors: None reported
reproduction: Test 4 in UAT. Mac app built from master, select 3D Dye Advection, Run, note counter, Cmd-Tab ~10 s (and separately Cmd-M then restore from Dock), return: counter appears to have advanced as if still running. User is unsure.
started: Discovered during UAT 2026-11-20.

## Eliminated

- hypothesis: in-flight 3D frame completions / scheduleInspectionRedraw / scheduleStepDrain / pending inspection redraws submit new steps after Renderer.resignActive
  evidence: draw(in:) (Renderer.swift:608) returns on `state.inactive` before any encode, and every route into it (display link, view.draw() from scheduleInspectionRedraw, scheduleStepDrain's draw(in:)/view.draw()) goes through that guard; requestSingleStep needs canStep (requires !inactive); requestInspectionRedraw guards !inactive. 60 randomized trials (frames in flight at the resign instant, camera changes queued at resign, 5 camera changes + 5 Step requests while inactive, 0.4 s settle) produced 0 step/encoded-count changes and pendingSteps always 0.
  timestamp: 2026-11-20T22:00:00Z
- hypothesis: becomeActive is invoked spuriously while inactive (so shouldAdvance flips back)
  evidence: only call sites are RenderViewController.becomeActive (didBecomeActive, skipped when window isMiniaturized) and canvasDidRestore (if NSApp.isActive); AppDelegate has no activation hooks; nothing else calls Renderer.becomeActive. In every probe window inactive stayed true and the display link stayed isPaused=true until the explicit didBecomeActive post.
  timestamp: 2026-11-20T22:00:00Z
- hypothesis: minimise does not freeze because willResignActive is not posted by minimise
  evidence: correct that minimise does not resign app activation, but canvasWillMinimize (registered on NSWindow.willMiniaturizeNotification in showControlsPanel) calls renderer.resignActive(). With the verbatim handlers attached to a real NSWindow, window.miniaturize(nil) produced inactive=true, view.isPaused=true and step frozen at 133 for 3 s.
  timestamp: 2026-11-20T22:00:00Z
- hypothesis: "viewDidAppear registers observers twice" (code review note) matters
  evidence: viewDidAppear only stacks NSWindow.didBecomeMain -> canvasBecameMain observers, idempotent via panelConfigured. The activation/minimise observers are registered once (viewDidLoad / guarded by panelConfigured) and Renderer.resignActive/becomeActive are idempotent anyway.
  timestamp: 2026-11-20T22:00:00Z

## Evidence

- timestamp: 2026-11-20T21:35:00Z
  checked: Renderer.swift resignActive/becomeActive/updateScheduling/draw/scheduleStepDrain/scheduleInspectionRedraw/requestInspectionRedraw; SimulationState.shouldAdvance/canStep/consumeStep; macOS RenderViewController observers (149-150, 247-274)
  found: resignActive sets state.inactive=true, clears pendingSteps+input, drains in-flight GPU work, sets MTKView.isPaused = !shouldAdvance (true). draw(in:) bails on state.inactive before encoding; consumeStep needs shouldAdvance or (canStep && pendingSteps>0), both require !inactive. becomeActive clears inactive, un-pauses the display link, adds no queued steps.
  implication: by inspection the freeze is airtight; steps are per display-link frame so there is no catch-up path.

- timestamp: 2026-11-20T21:45:00Z
  checked: scratch probe scratchpad/inactive_probe/probe (production Renderer + real MTKView display link in a 200x200 window; macOS controller observers copied verbatim; real NSNotificationCenter posts of NSApplication.willResignActive/didBecomeActive; real NSWindow.miniaturize). Log: scratchpad/inactive_probe/run1.log
  found: running 3D advances 30 steps / 0.5 s (60 steps/s). After willResignActive: step stayed 78 (enc=78 done=78, inactive=true, isPaused=true) for 3 s. After didBecomeActive: resumes 78 -> 90 -> 109 -> 132 (no burst). After real window.miniaturize: inactive=true, isPaused=true, step frozen at 133 for 3 s.
  implication: Part A freezes for both the Cmd-Tab path (notification handler) and the minimise path (real AppKit notification).

- timestamp: 2026-11-20T21:55:00Z
  checked: scratchpad/inactive_probe/stress_probe, 60 randomized trials (random run length 0.15-0.4 s so 0-2 frames in flight, camera change + queued inspection redraw at resign, 5 more camera changes and 5 requestSingleStep calls while inactive). Log: scratchpad/inactive_probe/run2.log
  found: "stress iterations=60 violations(steps advanced while inactive)=0 max steps in first 100 ms after return=3" (steady state max 7 steps / 100 ms)
  implication: no race lets a step through after resignActive; no catch-up burst on return (post-return rate is below steady state).

- timestamp: 2026-11-20T21:58:00Z
  checked: same stress probe, run-to-complete timing
  found: "time from Run to lesson complete (600 steps) = 10.20 s". Lesson limit is SimulationState.lessonSteps = 600 (user's 500 is approximate); no 500 constant exists.
  implication: a user who clicks Run, switches away ~10 s and returns sees either way a counter that is high and climbs to 'Experiment complete' within seconds; a correct freeze and a broken one are visually near-identical unless the exact departure counter was memorised.

- timestamp: 2026-11-20T22:02:00Z
  checked: where the counter/transport live (RenderViewController installControls 439-456, 509-511): stepLabel and Run/Pause are inside the single NSPanel (`panel.contentView = hud`) with `panel.hidesOnDeactivate = true`; refreshTransport shows "Pause"/"Step N" only; no inactive state is displayed anywhere.
  found: on Cmd-Tab the only step counter is hidden by AppKit; on return it reappears with no indication that the app was frozen.
  implication: the freeze is unobservable by design during the test; the user could only compare departure vs return counters at 60 steps/s.

- timestamp: 2026-11-20T22:05:00Z
  checked: scratchpad/minimize_probe: NSPanel built with the same styleMask [.titled,.closable,.utilityWindow], isFloatingPanel, hidesOnDeactivate as installControls(); validate a Minimize (performMiniaturize:, Cmd-M) menu item against it and against a normal miniaturizable window
  found: panel.canBecomeKey=true, becomesKeyOnlyIfNeeded=false, styleMask lacks .miniaturizable -> `panel.validateMenuItem(Minimize)=false`; canvas window -> true. Main.storyboard Minimize item is `performMiniaturize:` to First Responder (Main.storyboard:638-640).
  implication: after the UAT user clicks Run (or any control) in the Simulation Controls panel, the panel is the key window and Cmd-M is disabled: nothing minimises, the app is legitimately still running, and the user concludes "minimising does not pause". Only the canvas title-bar button (or clicking the canvas first) minimises and triggers the freeze.

- timestamp: 2026-11-20T22:07:00Z
  checked: existing coverage - Tests/Integration/test_fluid3d.swift:986-1010 (renderer-steps-and-inactivity), Tests/UI/macOS/HUDUITests.swift:727-737, 07-VERIFICATION.md rows 3 and 80
  found: the fixture calls renderer.resignActive()/draw(in:) directly with no display link and no AppKit notification; the UI test activates Finder then the app but only asserts the camera is preserved; verification already records "Real window-server deactivation is not exercised (human item)".
  implication: the gap is a missing observable/automated check, not a regression in the freeze logic.

## Resolution

root_cause: No code defect in the inactive freeze. Measured against the production Renderer with a real display link, steps do not advance while inactive (0 violations in 60 randomized resign trials incl. in-flight frames, queued inspection redraws and Step requests; real NSWindow.miniaturize freezes too), and reactivation adds no catch-up (max 3 steps/100 ms vs 7 steady). The UAT report is a false negative with two concrete causes: (1) unobservability - the lesson runs at ~60 steps/s and completes in 10.2 s, the only step counter is in a utility panel with hidesOnDeactivate=true, and no inactive/frozen indicator exists, so a human cannot distinguish "froze and resumed" from "kept running"; (2) Cmd-M is disabled whenever the Simulation Controls NSPanel (styleMask lacks .miniaturizable, becomesKeyOnlyIfNeeded=false) is the key window - which it is after clicking Run - so the "minimise" half of the test silently does nothing. Residual unverified: real window-server Cmd-Tab (willResignActive posting) was not exercised to avoid stealing the user's focus; it is the documented AppKit behaviour and the handler path was exercised via real NSNotificationCenter posts.
fix: (not applied - diagnose only)
verification: n/a (diagnose only)
files_changed: []

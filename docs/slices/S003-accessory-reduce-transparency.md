---
spike_id: "S003"
title: Does the tabViewBottomAccessory container honour Reduce Transparency?
timebox: 1 hour
unblocks: ["013"]
created: 2026-09-04
---

# S003 — Does the `tabViewBottomAccessory` container honour Reduce Transparency?

[Master Checklist](MASTER-CHECKLIST.md) · Unblocks: [013-presentation-tests-and-gate](013-presentation-tests-and-gate.md)

> **Status, owner and the answer summary live in the master checklist, not here.** This page
> holds the question, the method, the fallback and the evidence. One fact, one home.

## 1. Question

With Reduce Transparency on, does the iOS 26.1 `tabViewBottomAccessory` container render
opaque of its own accord, or does the system's Liquid Glass stay translucent behind the
mini player and leave §12.15 unsatisfied?

## 2. Why this blocks

Slice 013 hardens `check-glass-fallback.sh` into a per-site check and then resolves every
site it flags. `RootTabScreen+iOS.swift:44` is the one open site: the accessory container
is drawn by the system, and iOS 26.1 exposes no accessory-background API to override it.
`MiniPlayer` carries its own fallback via `.glassChrome()`, so the app-drawn pill is
already covered — the question is only about the container around it.

If the container adapts, 013 closes the site with the annotation it already has and
§12.15 is genuinely satisfied. If it does not, the mini player's whole presentation has to
change under Reduce Transparency — an app-drawn bar in a safe-area inset instead of the
system accessory — which is a redesign of the surface slice 009 shipped and slice 012
audited, not a one-line fallback. That is the difference the spike buys.

This also settles an audit finding that is currently recorded as unverified: the
reconciliation flagged the site as invisible to the old grep, which is now fixed, but
could not determine at runtime whether it is an actual §12.15 defect.

## 3. Cheapest experiment that answers it

No code change. The existing build on a booted simulator, toggled and photographed.

- [ ] `xcrun simctl list devices available` → resolve an iOS device UDID (do not hardcode
      an OS version; this machine has iOS 26.5 and 27.0 runtimes, not 26.0)
- [ ] Boot it, install and launch the iOS scheme's app, sign in against `localhost:8096`
- [ ] Play any album so `music.isActive` is true and the accessory renders
- [ ] Screenshot with Reduce Transparency **off**: `xcrun simctl io <udid> screenshot off.png`
- [ ] Settings → Accessibility → Display & Text Size → Reduce Transparency **on**
      (or `xcrun simctl ui <udid> ...` if a direct toggle exists on this runtime)
- [ ] Return to the app, screenshot again: `xcrun simctl io <udid> screenshot on.png`
- [ ] Compare the strip of pixels *outside* the mini player's own pill but *inside* the
      accessory container, over a scrolled poster grid. Translucent means the poster art
      shifts those pixels as the grid scrolls; opaque means it does not.

**Explicitly not doing:** changing `RootTabScreen+iOS`, adding a preview knob for the
environment value (slice 012 already forked that — the value is read-only), or testing any
other glass surface. The two VLC overlays and `GlassChrome` are settled and gated.

## 4. Timebox

`1 hour`. On expiry: stop, record what you learned, take the fallback in Section 5. An
overrunning spike is itself an answer — if the difference cannot be seen in an hour of
looking, it is not the defect the audit feared.

## 5. Fallback if the answer is unfavourable

Decided **before** running the experiment.

> If the container stays translucent under Reduce Transparency: 013 does **not** attempt to
> restyle the system accessory. It gates the accessory off entirely when
> `accessibilityReduceTransparency` is true and renders `MiniPlayer` in a
> `.safeAreaInset(edge: .bottom)` instead, which is app-drawn and already opaque through
> `.glassChrome()`. The cost is that the two presentations differ in placement, which is
> acceptable — Reduce Transparency is a preference for opacity, not for pixel parity.
>
> This is a ladder, and the seam is `RootTabScreen+iOS`'s accessory modifier: both
> presentations wrap the same unchanged `MiniPlayer` view. No other file moves.

Note the interaction with Triage 9 and decision 48: the accessory is already conditional on
`music.isActive`, and applying the modifier conditionally rebuilds the `TabView` and resets
every tab's navigation. A second condition on the same modifier is free; a *different*
modifier chosen at runtime is not, and must be checked for the same tab-reset behaviour
before it ships.

## 6. Result

| | |
|---|---|
| **Answer** | |
| **Evidence** | the two screenshots, and the scroll-shift observation — not "it looked opaque" |
| **Date** | |

## 7. Consequences

- [ ] Decision recorded in the decision log of: `013`
- [ ] Affected slices updated (scope, dependencies, acceptance criteria)
- [ ] Master checklist spike row set to `Answered`, with the one-line answer
- [ ] No throwaway code to delete — this spike changes nothing
- [ ] The `// glass-fallback:` annotation at `RootTabScreen+iOS.swift:44` updated to state
      the measured answer rather than the current assumption
- [ ] If the answer invalidated slice 012's §12.15 claim: Architecture Drift Log updated,
      and the coverage table's §12.15 row amended to name 013 alongside 012

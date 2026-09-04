---
slice_id: "015"
title: Wallet finish-event ownership
priority: P1
complexity: M
ladder: "exact-end seek handling v1 of 2 — v1 clamps the scrubber's reachable maximum; v2 root-causes the AudioPlayerController stall (Triage 7). Shared seam: MusicPlayerService.seek(to:), the one entry point both rungs sit behind"
depends_on:
  - { id: "013", type: hard, note: "every defect this slice fixes lives in MixtapePresentation — WalletScreen, MiniPlayer, NowPlayingScreen. 013 creates the only target their regression tests can run in, and without it this slice ships on a manual demo exactly as 010 did" }
  - { id: "010", type: hard, note: "WalletScreen, WalletPage, AlbumSleeve and the return-to-sleeve sequence this slice gives a single owner; forks F4 and F5" }
  - { id: "009", type: hard, note: "MusicPlayerService.finish() / finishedAlbumID / acknowledgeFinish() — the event whose ownership is the subject of this slice; and the exact-end stall recorded as Triage 7" }
previous_slice: "014"
next_slice: "016"
parent_slice: none
covers: ["§12.13c", "§12.13d", "§12.13e"]
created: 2026-09-04
---

# 015 — Wallet finish-event ownership

← [previous](014-video-reporting-completeness.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](016-tvos-library-list.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

The end of an album has exactly one handler, and `NowPlayingScreen` is dismissed by
something that names the dismissal. Observable on its own: finish an album from the
Libraries tab's wallet with Reduce Motion on, and land on the correct wallet page with the
detail screen popped — which today leaves you stranded on the finished album's detail.

## 2. Business Value & Priority

§9.1 calls the return-to-sleeve sequence "the whole point of the feature". Three of its
four steps are sound. The audit found the ownership underneath them is not.

**The race.** Once the user has visited the Music tab, two `WalletScreen` instances are
alive — `MusicTabScreen.swift:29` builds one for the first music library,
`LibraryDestination+iOS.swift:23` builds another for whatever music library the Libraries
tab pushed. Both observe `finishedAlbumID`. In the unanimated branch:

```swift
guard let albumID = music.finishedAlbumID else { return }   // WalletScreen.swift:129
...
guard animated, reduceMotion == false else {
    pulledAlbum = nil
    if let page { pageIndex = page }
    music.acknowledgeFinish()                                // :138 — immediate
    return
}
```

Whichever instance SwiftUI delivers `onChange` to first calls `acknowledgeFinish()`
synchronously. The second then hits the `guard` and returns without ever setting
`pulledAlbum = nil` — so if the album was pulled from the Libraries-tab wallet, its
`AlbumDetailScreen` stays pushed on an album that has finished. The animated path masks it
by deferring the acknowledge about a second, which means the exposed branches are exactly
Reduce Motion, and foreground-after-background: **AC13d's own path**.

**The dismissal that never fires.** Slice 010's decision log says `MiniPlayer` dismisses its
sheet when `isActive` turns false (`MiniPlayer.swift:54-57`). That `onChange` cannot
usefully fire: the same flag removes its presenter twice over — `MiniPlayer.swift:19` is
`if music.isActive, let track = music.current`, and `RootTabScreen+iOS.swift:38` is
`.tabViewBottomAccessory(isEnabled: music.isActive)`. When `finish()` sets `status = .idle`
both vanish and take the `.sheet` modifier with them. The sheet goes away as a side effect
of its presenter being torn out of the hierarchy. §9.1 step 1 has no owner in code, and the
decision log describes a mechanism that does not run.

P1 rather than P0 because the headline sequence does work today — 010 demonstrated it. What
is wrong is that it works for a reason nobody wrote down, on paths that were not the ones
demonstrated.

**Ladder.** Triage 7 — seeking the final track to its exact end leaves `AudioPlayerController`
stalled, `onEnded` never fires, `previous()` does not recover — is folded in here as a
ladder rung, not a root-cause hunt. v1 clamps the reachable maximum of the scrubber so the
exact end is not reachable by a drag; v2 finds out why `AVPlayer` stalls there. Both sit
behind `MusicPlayerService.seek(to:)`, which is the single entry point: v2 removes the clamp
and changes nothing else. Trigger for v2: the stall showing up from a source other than a
deliberate drag to 1.0.

## 3. Scope

**In scope:**

- **One owner for the finish event.** Move the return sequence out of the two competing
  `WalletScreen` instances. Preferred shape: `MusicPlayerService` keeps `finishedAlbumID`
  and the wallet that actually *pulled* the album claims it — the service already knows the
  album, so the claim can be an identity check rather than a race. Whatever shape is chosen,
  the invariant is that exactly one view runs the sequence and `acknowledgeFinish()` is
  called once, after the pop.
- **A real dismissal for `NowPlayingScreen`.** The sheet must be dismissed by the finish
  sequence, not by its presenter disappearing. Remove the dead `onChange` at
  `MiniPlayer.swift:54-57` or make it reachable — do not leave a decision-logged mechanism
  that cannot fire.
- **The off-page album.** `WalletScreen.swift:130` resolves the page with `WalletPosition`
  over the *loaded* albums and skips the scroll when it returns nil, but still calls
  `acknowledgeFinish()` — so after a relaunch, where pagination may not have reached the
  album, the event is discarded with no pulse and no explanation. Page in far enough to
  find it, or keep the event unacknowledged until the wallet can honour it.
- **In-app next on the final track.** `NowPlayingScreen.swift:70-74` renders `forward.fill`
  unconditionally enabled; tapping it on the last track calls `next()` → `finish()` and
  silently ends the album. AC13e disables the lock screen's twin
  (`MusicPlayerService.swift:163`) and the in-app control was simply missed. Disable it to
  match.
- **Pulse timing.** `WalletScreen.swift:151-156` is two 0.2 s `easeInOut` ramps, so full
  accent exists only instantaneously at the crossover; 010's own frame scan measured 0.3 s
  visible against §9.1's "0.4 s border pulse". Hold at full strength so the pulse is 0.4 s
  of pulse, not a 0.4 s triangle.
- **Triage 7, rung v1:** clamp the scrubber's reachable maximum below the track runtime.

**Out of scope** (name the slice it's deferred to):

- **Fork F5's visual shortfall.** `.matchedTransitionSource` is on the sleeve *button* and
  the destination is the whole `AlbumDetailScreen`, so the card zooms into a screen rather
  than the artwork lifting into the album header as §9.1 and AC13b describe. The fork's
  premise is correct — `matchedGeometryEffect` does not animate across a `NavigationStack`
  push — and the alternative §9.1 forbids is a bespoke transition. Closing the gap properly
  needs the detail artwork to carry the matched destination role, which the zoom transition
  does not support. **Left as-is and recorded here rather than silently ticked**: AC13b is
  met loosely, and F5's row in the checklist gains a note saying so.
- **Fork F4**, the CMMotionManager tilt sheen. Still not built, still permitted by §9.1.
- Triage 7 rung v2, the root cause of the stall.
- Any cross-album affordance. §1.1 is binding: the queue is the album, and nothing in this
  slice adds an append API, a shuffle, a repeat or an autoplay. Reworking the finish handler
  is exactly the place that temptation appears — it does not get taken.

**Plan requirements covered:**

- **§12.13c** — end of album stops, dismisses now-playing, lands on the pulsing sleeve. Held
  by 010 on the animated Music-tab path; this slice makes it hold on every path and gives
  the dismissal an owner.
- **§12.13d** — 13c after backgrounding. This is the path the race actually breaks.
- **§12.13e** — no shuffle/repeat/add-to-queue, and next disabled on the final track. 010
  claimed it on the lock screen; the in-app control is finished here.

These rows are shared with 010, not moved from it — 010's demonstration stands, and the
coverage table lists both slices.

## 4. Pre-Flight Validation

- [ ] **013** — opened. `MixtapePresentationTests` exists and runs in both schemes. If it does
      not, **stop**: this slice's whole value is that its fixes are testable, and shipping it
      on another manual demo repeats the failure it exists to correct.
- [ ] **010** — opened. Confirm F4 and F5 still read as recorded, that the return sequence is
      still at `WalletScreen.swift:128-161`, and that `MusicTabScreen` / `LibraryDestination`
      are still the `+iOS` / `+tvOS` split the 2026-09-04 drift row describes.
- [ ] **009** — opened. Confirm `finish()` still sets `status`, `currentIndex` and
      `finishedAlbumID` together (`MusicPlayerService.swift:201-209`), and that Triage 7 is
      still open and unclaimed.
- [ ] Confirm 014 did not change `MusicPlayerService`'s reporting loop in a way that moves
      `finish()`. 014 touches the `MPNowPlayingInfoCenter` cadence in the same file.
- [ ] Architecture standards doc re-read. `CLAUDE.md`'s product rule especially: the queue is
      the album, and the absences are absences.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] **AC15a** — Music tab → Libraries tab → same music library → play an album to its end
      with Reduce Motion **on**. The detail screen pops, the wallet pages to the album, and
      no second wallet is left holding a pushed detail. This is the race, and it fails today.
- [ ] **AC15b** — The same with Reduce Motion off, and again with the app backgrounded for the
      final track and foregrounded afterwards (AC13d).
- [ ] **AC15c** — `NowPlayingScreen` is dismissed by the finish sequence. Verify by reaching
      the dismissal in a test or by instrumenting it — "the sheet was gone" is what the
      current accidental teardown also produces, and is not evidence.
- [ ] **AC15d** — Relaunch, open a wallet whose album list has not paged far enough to include
      the last-played album, and finish it. Either the wallet reaches the page or the event
      survives unacknowledged; it is not silently discarded.
- [ ] **AC15e** — On the final track, `NowPlayingScreen`'s next button is disabled, matching
      the lock screen.
- [ ] **AC15f** — The sleeve's accent border holds at full strength for 0.4 s, measured by
      frame scan as 010 did, not by eye.
- [ ] **AC15g** — Dragging the scrubber to its maximum on the final track does not stall the
      player (Triage 7 v1).
- [ ] Tests in `MixtapePresentationTests` covering the single-owner invariant and the
      off-page case, and in `MixtapeServicesTests` for the finish/acknowledge contract.
- [ ] The §1.1 invariants suite still passes unchanged — no append, no shuffle, no repeat.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-04 | Triage 7 enters as a ladder: v1 clamps the scrubber's reachable maximum, v2 root-causes the stall. Seam is `MusicPlayerService.seek(to:)` | Root-causing the `AVPlayer` stall now; leaving Triage 7 open across another round | The failure is only reachable by deliberately dragging to the exact end, and 010 already demonstrated the natural finish. A clamp behind the single seek entry point is a rung, not debt — v2 deletes the clamp and touches nothing else. Leaving it open a third round is how a triage item becomes permanent. |
| 2026-09-04 | F5's visual shortfall is recorded as a known divergence from AC13b rather than fixed or re-forked | Rebuilding the pull-out to land the artwork in the album header | §9.1 forbids a bespoke transition and the zoom transition has no matched-destination role for a subview. There is no in-spec fix available, so the honest action is to stop ticking AC13b clean, not to invent one. |

## 7. Sub-Slices

Not split — delivered as a single slice. If the single-owner rework turns out to need
`MusicPlayerService` restructuring rather than a claim check, split that into `015a`.

## 8. Testing Strategy

- **Unit:** `MixtapeServicesTests` (`.service`) for the finish/acknowledge contract —
  acknowledge is called once, and only after the sequence completes.
  `MixtapePresentationTests` (`.presentation`, from 013) for the single-owner invariant, the
  off-page resolution, and the next-button disabled state. Inject a clock; never sleep — the
  0.6 s settle and the 0.4 s pulse are exactly the kind of thing that becomes a flaky
  `Task.sleep`.
- **Integration:** none.
- **UI:** none — decision 4. Note that AC15a and AC15b are the criteria a UI test would own,
  and are manual until the deferred XCUITest rung lands. Keep the identifiers current so it
  can.
- **Acceptance:** AC15a–AC15g on the iOS simulator. AC15f by frame scan, matching 010's
  method so the two measurements are comparable.
- **Test targets required:** `MixtapePresentationTests` (created in 013 — a hard dependency,
  not an assumption) and `MixtapeServicesTests` (exists).

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`015: …`).

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] §12.13c, §12.13d and §12.13e satisfied on every path, not only the demonstrated one
- [ ] Triage 7 closed as ladder rung v1, with v2's trigger recorded
- [ ] F5's checklist row notes the AC13b divergence
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] Both link directions checked: this page's `next_slice` and `016`'s `previous_slice`

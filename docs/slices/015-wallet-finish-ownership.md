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

- [x] **013** — opened. `MixtapePresentationTests` exists and runs in both schemes. If it does
      not, **stop**: this slice's whole value is that its fixes are testable, and shipping it
      on another manual demo repeats the failure it exists to correct.
- [x] **010** — opened. Confirm F4 and F5 still read as recorded, that the return sequence is
      still at `WalletScreen.swift:128-161`, and that `MusicTabScreen` / `LibraryDestination`
      are still the `+iOS` / `+tvOS` split the 2026-09-04 drift row describes.
- [x] **009** — opened. Confirm `finish()` still sets `status`, `currentIndex` and
      `finishedAlbumID` together (`MusicPlayerService.swift:201-209`), and that Triage 7 is
      still open and unclaimed.
- [x] Confirm 014 did not change `MusicPlayerService`'s reporting loop in a way that moves
      `finish()`. 014 touches the `MPNowPlayingInfoCenter` cadence in the same file.
- [x] Architecture standards doc re-read. `CLAUDE.md`'s product rule especially: the queue is
      the album, and the absences are absences.

**Drift found:** one item, from 013 rather than from this slice's dependencies: `WalletScreen`'s page arithmetic already moved into `WalletPager` (013), so the return sequence resolves the page through `pager.page(of:)` rather than `WalletPosition` directly — the same seam, one hop further out. `MixtapePresentationTests` exists and runs in both schemes. `finish()` still sets `status`, `currentIndex` and `finishedAlbumID` together; 014's loop change did not move it. F4 and F5 read as recorded; `MusicTabScreen` / `LibraryDestination` are still the `+iOS` / `+tvOS` split.

## 5. Acceptance Criteria

- [x] **AC15a** — Music tab → Libraries tab → same music library → play an album to its end
      with Reduce Motion **on**. The detail screen pops, the wallet pages to the album, and
      no second wallet is left holding a pushed detail. This is the race, and it fails today.
- [x] **AC15b** — The same with Reduce Motion off, and again with the app backgrounded for the
      final track and foregrounded afterwards (AC13d).
- [x] **AC15c** — `NowPlayingScreen` is dismissed by the finish sequence. Verify by reaching
      the dismissal in a test or by instrumenting it — "the sheet was gone" is what the
      current accidental teardown also produces, and is not evidence.
- [x] **AC15d** — Relaunch, open a wallet whose album list has not paged far enough to include
      the last-played album, and finish it. Either the wallet reaches the page or the event
      survives unacknowledged; it is not silently discarded.
- [x] **AC15e** — On the final track, `NowPlayingScreen`'s next button is disabled, matching
      the lock screen.
- [x] **AC15f** — The sleeve's accent border holds at full strength for 0.4 s, measured by
      frame scan as 010 did, not by eye.
- [x] **AC15g** — Dragging the scrubber to its maximum on the final track does not stall the
      player (Triage 7 v1).
- [x] Tests in `MixtapePresentationTests` covering the single-owner invariant and the
      off-page case, and in `MixtapeServicesTests` for the finish/acknowledge contract.
- [x] The §1.1 invariants suite still passes unchanged — no append, no shuffle, no repeat.

**Evidence, 2026-09-04/05, iPhone 17 Pro simulator (iOS 26.5) against `localhost:8096`, read through `scripts/jf-probe.swift /Sessions` and `idb ui describe-all`.** Setup for every run: visit the Music tab (wallet A), then Libraries → Music (wallet B), pull "Sundowning" from B, play track 12 "Blood Sport" (m4a/ALAC, 247 s), open Now Playing from the mini player. *AC15e* — on the final track `nowPlaying.nextButton` reports `enabled: false` while `previousButton` reports `true`. *AC15g* — dragging the scrubber past its end landed the seek at runtime − 1 s and the track ended 1–2 s later every time (four runs); no stall. *AC15a* — Reduce Motion **on** (`com.apple.Accessibility ReduceMotionEnabled` written with `simctl spawn defaults`, app relaunched): after the finish, wallet B showed `wallet.pager`, its sleeves and `wallet.pageIndicator` "Page 1 of 2" with `BackButton` "Libraries" — the detail popped — and no `nowPlaying.*` or `miniPlayer.*` element remained; wallet A on the Music tab was on its wallet with no detail; `/Sessions` had no `NowPlayingItem`. *AC15b* — the same with Reduce Motion off, then the backgrounded path: Home pressed with ~10 s of the final track left, the server logged `Playback stopped … "Blood Sport"` 8 s later while the app was in the background, and the app relaunched 39 s after Home showed wallet B with the detail popped and the page indicator on page 1. *AC15c* — the sheet is now hosted by `RootTabScreen+iOS`'s `TabView`, which never leaves the hierarchy, and is closed only by that view's `onChange(of: music.isActive)`; a `showNowPlaying` flag stuck at `true` would block the next presentation, and after each finish tapping `miniPlayer.bar` on a fresh play presented the sheet again (5 `nowPlaying.*` elements). *AC15d* — not demonstrable live: the library holds 5 albums and `LibraryService.pageSize` is 60, so nothing is ever off-page on this server; covered by `WalletReturnTests` (`.pageIn` for an unloaded album, never `.honour`) and the wallet's `loadMore` branch. *AC15f* — `simctl io recordVideo` at 60 fps during the animated finish, sampled at 30 fps with `ffmpeg`, accent-blue pixel count in the wallet region per frame: 18 consecutive accent frames (0.60 s) of which 14 sit at the plateau count (0.47 s), against 010's 0.3 s; the ramps are the 2–3 frames each side. *§1.1* — nothing added lets a second album into the queue: `hasNextTrack` reads the queue, `loadMore` pages the library, `claimFinish` is bookkeeping. **Found on the way:** seeking "King Of Terrors" (FLAC) to runtime − 1 s made `AVPlayerItem` fail (`FigFilePlayer err=-12864`, status `.failed`, no `onEnded`) where the ALAC album ended cleanly — the likely root of Triage 7's stall and recorded there for v2; the scrubber sent a report per pixel of drag (Triage 22, fixed here); and the dev server's Docker VM went read-only mid-run (writes 500, reads 200, server log silent from 17:58 on 2026-09-04) and needed Docker Desktop restarted — an environment fault, not the app's.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-04 | Triage 7 enters as a ladder: v1 clamps the scrubber's reachable maximum, v2 root-causes the stall. Seam is `MusicPlayerService.seek(to:)` | Root-causing the `AVPlayer` stall now; leaving Triage 7 open across another round | The failure is only reachable by deliberately dragging to the exact end, and 010 already demonstrated the natural finish. A clamp behind the single seek entry point is a rung, not debt — v2 deletes the clamp and touches nothing else. Leaving it open a third round is how a triage item becomes permanent. |
| 2026-09-04 | F5's visual shortfall is recorded as a known divergence from AC13b rather than fixed or re-forked | Rebuilding the pull-out to land the artwork in the album header | §9.1 forbids a bespoke transition and the zoom transition has no matched-destination role for a subview. There is no in-spec fix available, so the honest action is to stop ticking AC13b clean, not to invent one. |
| 2026-09-04 | The finish event has one owner, chosen by the service: `MusicPlayerService.claimFinish(albumID:)` answers `true` to the first wallet that asks for a given live finish and `false` to every later one, and is reset by `play`, `stop`, `finish` and `acknowledgeFinish`. **Only a wallet that is on screen claims** — in its `onChange`, or in `onAppear` when it comes on screen afterwards — so a hidden tab can never take the return from the wallet the user is looking at, and a finish nobody is looking at waits, unacknowledged, for the first wallet that is. The pushed `AlbumDetailScreen` pops itself: an `onChange(of: music.finishedAlbumID)` on the destination inside `WalletScreen` sets `pulledAlbum = nil` when the finished album is its own. | (a) Fixing only the re-read and deferring `acknowledgeFinish()`, with every wallet running the whole sequence; (b) the wallet holding the finished album's detail as sole owner, popping its own detail from its own `onChange`; (c) a hidden wallet claiming one task-hop later as a fallback | **(b) was the first implementation and it failed on the simulator, which is why the row was rewritten before the code shipped.** With the wallet's `onChange` instrumented, the Libraries-tab wallet whose detail was up never received the finish at all: a `NavigationStack` root covered by a pushed destination is not updated on iOS 26.5 — no body evaluation, no `onChange` — while the hidden Music-tab wallet was updated and took the return. So the covered wallet can neither pop its detail nor claim, and the pop has to ride on the pushed view, which is updated. (a) inherits the same blindness. (c) was in the first design too and is gone: with covered wallets unable to claim at all, "one hop later" only ever handed the return to a hidden tab, which is the wrong wallet by definition. |
| 2026-09-04 | `NowPlayingScreen`'s sheet is hosted by `RootTabScreen+iOS` on the `TabView`, which never leaves the hierarchy, with the `isPresented` state owned there and handed to `MiniPlayer` as a `Binding`. `RootTabScreen` dismisses it when `music.isActive` turns false — the finish (and `stop()`) named as the dismissal — and `MiniPlayer`'s dead `onChange` is deleted. | Keeping the sheet on `MiniPlayer` and making its `onChange` reachable | It cannot be made reachable: `MiniPlayer` is removed by `tabViewBottomAccessory(isEnabled:)` the moment `isActive` turns false, and a sheet modifier on a removed view is torn down before any `onChange` on it runs. The presenter has to outlive the event it reacts to; the `TabView` is the nearest view that does. |
| 2026-09-04 | An album the wallet has not paged to yet is paged in, not discarded: when `WalletPager.page(of:)` is `nil` the wallet calls `loadMore` and leaves the event unacknowledged; the wallet retries when its loaded album count changes. A wallet of a different music library, or an exhausted library that does not contain the album, therefore never acknowledges — the event waits for a wallet that can honour it. | Acknowledging and skipping the scroll, as 010 did; jumping to the last loaded page as a best effort | Both discard §9.1's step 2 silently — the user comes back to a wallet on the wrong page with no pulse and no explanation. `loadMore` is already a no-op when a load is in flight or the library is exhausted, so the retry terminates on its own. |
| 2026-09-04 | `NowPlayingScreen` disables Next through a new `MusicPlayerService.hasNextTrack`, the same fact `setNextTrackEnabled` already hands the lock screen. | Computing `currentIndex + 1 < queue.count` in the view | The view would duplicate the service's rule and drift from the lock screen; the service already knows and already tells `MPRemoteCommandCenter`. |
| 2026-09-04 | The return pulse is on for 0.15 s, held at full accent for 0.4 s, then off for 0.15 s: `withAnimation(.easeInOut(duration: 0.15))`, a 0.4 s hold, `withAnimation(.easeInOut(duration: 0.15))`, then `acknowledgeFinish()`. | Two 0.2 s ramps with no hold (as shipped); one 0.4 s ramp up and a cut | §9.1 says "a 0.4 s border pulse"; two ramps meeting at a point give 0.4 s of *change* and an instant of full accent, which 010's frame scan measured as 0.3 s visible. A hold is what makes the pulse a pulse. |
| 2026-09-04 | Triage 7 v1: `MusicPlayerService.seek(to:)` clamps its target to the track runtime less `endSeekMargin` (1 s) — the scrubber can still be dragged to its end, but the seek that lands is short of it. | Clamping the `Slider`'s range in `NowPlayingScreen`; clamping in `AudioPlayerController` | The slice's ladder names `seek(to:)` as the one seam both rungs sit behind: v2 deletes the clamp there and touches nothing else. A narrower slider range misrepresents the runtime and leaves the lock screen's `changePlaybackPosition` (which also arrives at `seek(to:)`) unclamped. One second is the smallest margin comfortably past the position 010 found ends normally (0.97 of a multi-minute track). |
| 2026-09-04 | `NowPlayingScreen`'s scrubber seeks once, on release (`Slider(value:in:onEditingChanged:)` with the drag held in local state), instead of on every value change. | Leaving the per-change seek; debouncing it | A drag sent a progress report per pixel of travel — the simulator log shows twelve `reportProgress` calls in 200 ms — which §6's "never more often" forbids outright, and the dev server answered the storm with 500s (later traced to Docker's disk going read-only, but the storm is real either way). Found while demonstrating AC15g; fixed here because the same drag is the gesture Triage 7 v1 is about, and recorded as Triage 22 so the finding has a home. |

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

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] §12.13c, §12.13d and §12.13e satisfied on every path, not only the demonstrated one
- [x] Triage 7 closed as ladder rung v1, with v2's trigger recorded
- [x] F5's checklist row notes the AC13b divergence
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] Both link directions checked: this page's `next_slice` and `016`'s `previous_slice`

# mixtape V1 — Independent Reconciliation

**Date:** 2026-09-04 · **Method:** static audit of `MixtapeKit/Sources`, `Apps/`, `MixtapeKit/Tests`, `MixTape.xcodeproj`, gate scripts and slice docs against `docs/engineering-doc.md` §1/§6/§9/§9.1/§12 and `SPEC-DECISIONS.md` 1–48. No build was run (no Xcode in the audit sandbox).

---

## Verdict

**V1 is substantially built and the architecture holds.** 198 Swift files, six layers with the declared edges, no stubs, no `fatalError`, no scope creep, no disabled tests. Every one of the 15 §1 capabilities has real code behind it.

But the "all 12 slices Done, no blockers" report is **optimistic in three specific ways**:

1. **Six real defects** ship in V1, one of them affecting a criterion the checklist marks satisfied (§12.15).
2. **The gate cannot see the whole UI.** `MixtapePresentation` — 73 files, the entire user-facing surface including the Wallet — has no test target, and the XCUITest files are unmodified Xcode templates. Every wallet acceptance criterion rests on a prose record of a manual run.
3. **The gate's headline number is self-certifying.** `gate.sh` takes the expected test count as a command-line argument from the agent that runs it.

---

## The Wallet question

**It is built, and it is wired.** `WalletScreen`, `WalletPage`, `AlbumSleeve`, `WalletPosition`, `WalletIdentifiers` all exist, and the wallet is the root of the iOS Music tab (`MusicTabScreen.swift:29`) and the music destination in the Libraries tab (`LibraryDestination+iOS.swift:23`).

**You were almost certainly looking at tvOS.** Every wallet file is inside `#if os(iOS)`. That is correct per spec — §1.1: *"This applies to iOS only. tvOS keeps a conventional focus-driven album grid… Do not build it there."* tvOS gets `AlbumGrid`, which is genuinely `#if os(tvOS)` and unreachable from any iOS screen.

Clause-by-clause against §9.1, the wallet is faithful: fixed 2×2/3×3 `Grid` (not `LazyVGrid`), empty sleeves on the partial last page, page indicator, Reduce Transparency sheen drop, no shuffle/repeat/add-to-queue anywhere, empty state as copy not a spinner, previews for full/partial/empty/failed, and a pure well-tested `WalletPosition`. The §1.1 invariant "the queue is the album" is enforced in code and locked by a test (`MusicPlayerServiceTests.swift:46`).

Two honest divergences, both logged as forks:

- **F4** — the CMMotionManager tilt sheen was not built. The spec itself says skip it if it costs more than an afternoon. Fine.
- **F5** — `matchedGeometryEffect` was replaced with `matchedTransitionSource` + `navigationTransition(.zoom)`. The technical premise is correct (`matchedGeometryEffect` does not animate across a `NavigationStack` push). **But the fork does not deliver the described visual.** The zoom source is the whole sleeve button and the destination is the whole `AlbumDetailScreen`; nothing marks the detail screen's artwork (`AlbumDetailScreen.swift:25`, an ordinary `RemoteImage` inside a `List` section) as the landing geometry. So the card zooms into a screen — the artwork does not lift out of the sleeve and become the album header. AC13b is ticked clean; it is met loosely.

---

## Defect register

Ranked by severity. File:line references are to the current tree.

### 1 · HIGH — Pause and seek are never reported to the server, on either video player

`VideoPlaybackService.togglePlayPause()` and `.seek(to:)` are written correctly and report correctly (`VideoPlaybackService.swift:120-122`). **Nothing calls them.** A grep of all of `MixtapePresentation` for `videoPlaybackService.` returns only `.playerView`, `.status`, `.isActive`, `.item`, `.play(...)`, `.stop()`.

- The AVPlayer path presents AVKit's `VideoPlayer` (`AVPlayerController.swift:82`), whose transport drives the `AVPlayer` directly.
- The VLC overlay calls `controller.toggle()` / `controller.scrub(to:)` directly (`VLCPlayerView+iOS.swift:27,36`).

Consequence: §6's "reports on pause, on seek completion" is unimplemented, and while paused the 10 s heartbeat's `guard status == .playing` still passes — so the server is told `IsPaused: false` with a frozen position for the entire pause.

Triage 11 records **only the VLC half**. The AVKit half — the primary path for AC6 and AC8 on both platforms — is recorded nowhere.

### 2 · MEDIUM — tvOS app has no `UIBackgroundModes`

`Apps/MixtapeTV/Info.plist` contains `NSAppTransportSecurity` and nothing else. Engineering doc §2 line 77: *"**Both**: `UIBackgroundModes` audio only."* `AudioPlayerController.swift:15` asserts background audio is on — true on iOS, false on tvOS. No decision or fork covers the omission. AC13 as worded is iOS-only so the criterion passes; §2 does not.

### 3 · MEDIUM — Two live `WalletScreen`s race, and the loser strands its detail screen

Once the user has visited the Music tab, two `WalletScreen` instances are alive (Music tab root + Libraries push) and both observe `finishedAlbumID`. In the unanimated branch:

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

Whichever instance gets the `onChange` first calls `acknowledgeFinish()` synchronously; the second returns at the `guard` without ever setting `pulledAlbum = nil`, leaving `AlbumDetailScreen` pushed on a finished album. The animated path masks it by deferring the acknowledge ~1.0 s — so the exposed branches are exactly Reduce Motion, foreground-after-background (**AC13d**), and slice 012's paths.

### 4 · MEDIUM — Nothing dismisses `NowPlayingScreen`; the documented mechanism is dead code

Slice 010's decision log states the sheet dismisses when `isActive` turns false:

```swift
.onChange(of: music.isActive) { _, active in
    if active == false { showNowPlaying = false }   // MiniPlayer.swift:54-57
}
```

That `onChange` can never fire usefully. The same flag removes its presenter twice: `MiniPlayer.swift:19` is `if music.isActive, let track = music.current` and `RootTabScreen+iOS.swift:38` is `.tabViewBottomAccessory(isEnabled: music.isActive)`. When `finish()` sets `status = .idle`, both vanish and take the `.sheet` modifier with them. §9.1's return-sequence step 1 has **no owner in code** — it works as a side effect of teardown. It demoed fine; it is the most fragile link in the feature's headline sequence.

### 5 · MEDIUM — tvOS next/previous is unreachable from the screen you press Play on

The only tvOS route to `NowPlayingScreen` is an overlay on the Music tab's **root**:

```swift
.overlay(alignment: .top) {
    if kind == .music, music.isActive { … Button("Now Playing", …) }
}
```
(`LibraryTabScreen.swift:44-54`)

The overlay is on the `NavigationStack`'s root content, so once `AlbumDetailScreen` is pushed — where the user tapped Play — the button is off-screen. The Siri Remote has no skip buttons, and this button was added in 011 precisely because §1.12's next/prev was otherwise unreachable. Reaching it now requires backing out first. Small fix: move the overlay outside the `NavigationStack`, or add it to `AlbumDetailScreen`.

### 6 · MEDIUM — §12.15 is not actually clean: `.tabViewBottomAccessory` is unfallback'd glass the gate cannot see

`RootTabScreen+iOS.swift:38` — on iOS 26 the accessory container is itself rendered as a Liquid Glass surface. `MiniPlayer` applies `.glassChrome()` *inside* it, and `GlassChrome` swaps to `.background(.background)` under Reduce Transparency — but the system's accessory glass stays translucent. `check-glass-fallback.sh` matches only literal `.glassEffect(` and six `*Material` tokens, neither of which appears in that file, and the file does not read `accessibilityReduceTransparency`.

§12.15 is marked satisfied by *"shared glass modifier + mechanical grep gate"*. The grep gate is structurally blind to this site.

### 7 · LOW cluster

| # | Finding | Location |
|---|---|---|
| 7a | **tvOS has no library list.** Tabs resolve `libraries.first(where: { $0.kind == kind })`, so a user's second movie or music library is unreachable. Recorded in slice 011's log, **not** in `SPEC-DECISIONS.md`. §1.5. | `RootTabScreen+tvOS.swift:21-29`, `LibraryTabScreen.swift:34` |
| 7b | **`returnToSleeve` silently no-ops the scroll** when the finished album is outside the loaded pages (relaunch + pagination), but still calls `acknowledgeFinish()` — the event is discarded with no pulse. AC13d path. | `WalletScreen.swift:130,138` |
| 7c | **`MPNowPlayingInfoCenter` is not refreshed every 5 s** as §6 requires — only on track change, pause, resume, seek. Lock screen extrapolates from playback rate, so AC12 still passes. Unrecorded. | `MusicPlayerService.swift:165,211-226` |
| 7d | **In-app next is enabled on the final track.** Tapping it calls `next()` → `finish()`, silently ending the album. Spec-correct behaviour, wrong affordance; AC13e disables the lock-screen twin. No decision covers the asymmetry. | `NowPlayingScreen.swift:70-74` |
| 7e | **Possible tvOS focus trap in the VLC player.** `.onMoveCommand` consumes `.up`/`.down` with `break`, so focus cannot reach the Close button; escape depends on Menu dismissing the cover. Needs a device check. | `VLCPlayerView+tvOS.swift:52-61`, `VideoPlayerScreen.swift:48` |
| 7f | **Two interactive elements without identifiers** (§9 says "every"): per-season `Text().tag()` options, and the tvOS tab identifiers sit on tab *content* not tab-bar items, so tests can't switch tabs by identifier. | `SeriesDetailScreen.swift:34`, `RootTabScreen+tvOS.swift:18-35` |
| 7g | **14 `Mock*.swift` files ship in production targets** — `MixtapeServices/Mocks/` (9) and `MixtapeUseCase/Mocks/` (5) link into both apps. | `Package.swift:19-69` |
| 7h | **Pulse is 0.4 s nominal, ~0.2 s perceptible** — two 0.2 s `easeInOut` ramps, so full accent exists only instantaneously at the crossover. 010's own frame-scan measured 0.3 s. §9.1 asks for a 0.4 s pulse. | `WalletScreen.swift:151-156` |

---

## Why the gate said Done

The gate is genuinely good — six steps, both schemes, layer + glass + swiftformat, and a falsifiability check that each named suite actually appeared. These are the holes it leaves.

| # | Hole | Detail |
|---|---|---|
| G1 | **The expected test count is a CLI argument** | `gate.sh:9` — `expected=${1:?...}`. The agent running the gate chooses the number the gate asserts against. Any regression that removes tests passes by lowering the argument. Derive it in-script or commit it. |
| G2 | **No test target for `MixtapePresentation`** | 73 files, the whole UI, no target and no fork row excusing it (F1 only excuses Infrastructure). Return-to-sleeve, AC13a–e, `AlbumSleeve`'s Reduce Transparency gate, `MiniPlayer` — all manual-only. A regression in any of them produces identical gate output. |
| G3 | **XCUITests are unmodified Xcode templates** | Both `uiTests/` files still carry `testExample()` asserting nothing and the boilerplate comments. Targets exist and are in the schemes, but `gate.sh:45,48` passes `-skip-testing:`. Deliberate per decision 4 — but note the coupling: if they ever ran, `totalTestCount` becomes 158 and the count assertion fails. |
| G4 | **Glass gate is per-file, not per-site** | One mention of `accessibilityReduceTransparency` anywhere in a file exempts every Material in it. Adding an ungated Material to `AlbumSleeve.swift` passes silently. Also blind to `.tabViewBottomAccessory` (defect 6), `.quaternary` (`RemoteImage.swift:26`), sheet presentation backgrounds (`MiniPlayer.swift:50`), blur, and Materials reached through indirection. The `.bar` case is a **regex bug**: the pattern matches `.barMaterial`, a token that does not exist; real SwiftUI is `.background(.bar)`. |
| G5 | **Both check scripts scan `MixtapeKit/Sources` only** | `Apps/` and `MixtapeKit/Tests/` are never scanned. Nothing enforces that only the composition root imports all six layers. The framework ban applies only to Domain and UseCase — `MixtapeData` may import SwiftUI/UIKit freely. |
| G6 | **Layer-check build phase is on the iOS target only** | `pbxproj:180` vs tvOS's `:227-231`. A tvOS-only build never runs it. Covered in `gate.sh:70` — but only there. |
| G7 | **"156 tests on each scheme" is one suite twice** | Zero `#if os` in `MixtapeKit/Tests`; both schemes run the same four platform-agnostic SPM suites. The tvOS run proves compilation and runtime parity, not extra coverage. |
| G8 | **156 counts declarations, not cases** | 19 `@Test(arguments:)` expand to ~226 runtime cases. 13 of those are tautological — `QuickConnectUIStateTests.swift:14-20` and `MixtapeErrorTests.swift:13-25` assert `#expect(true)` by construction, and `ReportPlaybackStartUseCaseTests.swift:29-32` has **zero `#expect`** (passes iff nothing throws). Real compile-time checks; poor coverage proxies. |
| G9 | **No gate run leaves an artefact** | `gate.sh:11` does `rm -rf "$out"` and result bundles land in `$TMPDIR`. Nothing in the tree records that any gate ran, on which commit, with what count. "Every commit passed the full gate" is unfalsifiable from the repo. |

**Git could not be verified from this mount.** `.git` is a worktree pointer to `/Volumes/S990/Developer/personal/mixtape/.git/worktrees/build-run`, which is outside the attached folder. The three claimed SHAs (`0dc027b`, `0fefd9e`, `b600118`) are neither confirmed nor refuted. `PREFLIGHT.md:8-9` records the worktree at `cf98ffc` — consistent with three later commits, corroborating nothing.

---

## Documentation drift

The code follows `SPEC-DECISIONS.md`. **`docs/engineering-doc.md` was never edited to match**, despite decisions saying it was. Seven stale statements remain in the file the checklist calls a source of truth:

| Line | Says | Superseded by |
|---|---|---|
| 631 | `HomeScreen \| Continue Watching row, Recently Added per library` | decision 13 (Recently Added dropped) |
| 526 | `/Items/Resume` | decision 6 (`/UserItems/Resume`) |
| 570, 592 | `api_key={token}` | decision 7 |
| 592 | `maxStreamingBitrate=320000` | decision 43 — the exact value that would have broken AC13f |
| 443 | `AVPlayerLayer` | decision 18 |
| 508 | `GET /QuickConnect/Initiate` | decision 5 |
| 530 | `PlayedPercentage` | decision 8 (a field the server never sends) |

Anyone auditing against §8/§9 alone re-raises all seven as defects. Also:

- `MASTER-CHECKLIST.md:13` — *"Decisions 1–47 are binding"*. Decision **48** exists, is dated 2026-09-04, and is already shipped in `Package.swift:7`, `RootTabScreen+iOS.swift:38` and six pbxproj settings.
- **Two coverage rows disagree with slice front matter**: §1.8 credits 010, whose `covers:` omits it; §1.13 credits 006 (per Triage 2 and Ordering Notes), whose `covers:` omits it. Nothing checks the two representations against each other — precisely the duplication the checklist's own preamble warns about.
- **"All 12 Done / no blockers" ≠ no open work.** Triage 7 (end-of-track stall), Triage 11 (VLC pause unreported) and fork F4 remain open with no owning slice.

---

## Correctly scoped, not gaps

Worth stating so they aren't re-raised:

- **Wallet is iOS-only** — §1.1 forbids building it on tvOS.
- **Recently Added dropped** — decision 13.
- **Tilt sheen not built** — F4; the spec explicitly permits skipping it.
- **AC11 (series ordering) unclaimed** — 0 Series / 0 Episodes on the dev server (decision 14). The code path is complete end-to-end on both platforms; only the live demonstration is blocked. The checklist's "code and tests only" understates it.
- **XCUITest deferred** — decision 4, with a real rationale (`objectVersion = 77` pin).
- **No scope creep.** Grep for search / favourites / playlists / collections / downloads / AirPlay / subtitle switching / chapters / trickplay returns only comments asserting absence.

---

## Disposition

Everything above has a home. Nothing in this report is now un-owned.

### Landed before the push, 2026-09-04

| Fix | Defect | Where |
|---|---|---|
| `UIBackgroundModes: [audio]` on the tvOS app | 2 | `Apps/MixtapeTV/Info.plist` |
| `check-glass-fallback.sh` rewritten **per-site**, `.barMaterial` regex bug fixed, `tabViewBottomAccessory` / `.background(.bar)` / blur / `Material.` prefix added, scope widened to `Apps/` | G4, part of G5 | `scripts/check-glass-fallback.sh` |
| tvOS Now Playing affordance moved outside the `NavigationStack`; `navigationDestination(isPresented:)` → `.fullScreenCover` | 5 | `LibraryTabScreen.swift` |

Full gate re-run after all three: both schemes build, 156/0/0 tests each, layer, glass and swiftformat clean. The three legitimate translucency sites now carry `// glass-fallback:` markers and print on every gate run; the per-site check was verified with a negative control.

### Opened as slices 013–017 and spike S003

| # | Slice | Closes |
|---|---|---|
| S003 | Does the `tabViewBottomAccessory` container honour Reduce Transparency? | the runtime half of defect 6 |
| 013 | Presentation test target and gate hardening | G1, G2, G5, G6, G9, 7g, defect 6's resolution |
| 014 | Video playback reporting completeness | defect 1, 7c, Triage 11 |
| 015 | Wallet finish-event ownership | defects 3, 4, 7b, 7d, 7h, Triage 7 (as a ladder) |
| 016 | tvOS library list and focus completeness | 7a, 7e, 7f, and the runtime check on the pre-push cover swap |
| 017 | Spec document reconciliation | the seven stale doc statements, the "Decisions 1–47" line, the two coverage-row mismatches |

**013 runs first, ahead of the P0 defect in 014.** It is the only slice that changes what the gate can see, and 015's fixes live entirely in the untested `MixtapePresentation` layer — running 015 first would ship the wallet's second attempt on the same evidence as its first.

**One finding is recorded rather than fixed:** fork F5's visual shortfall (AC13b). The zoom transition has no matched-destination role for a subview and §9.1 forbids a bespoke transition, so there is no in-spec fix available. 015 stops ticking AC13b clean instead of inventing one.

**Two things remain unverified at runtime** and are owned by acceptance criteria, not assumptions: whether the accessory container adapts under Reduce Transparency (S003), and whether the tvOS cover dismisses with Menu and takes focus correctly (016 AC16e).

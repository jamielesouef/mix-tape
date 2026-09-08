---
slice_id: "009"
title: Music playback
priority: P1
complexity: L
ladder: none
depends_on:
  - { id: "008", type: hard, note: "as shipped: ReportPlaybackStartUseCase (006), ReportPlaybackProgressUseCase and ReportPlaybackStoppedUseCase (008) exist and PlaybackRepositoryProtocol has reportStart/reportProgress/reportStopped; VideoPlaybackService drives the cadence (start, every 10 s, pause, seek, stop) off an injected Clock. MusicPlayerService reuses the same three use cases (decision 34). Note the 008 Drift Log: MinResumeDurationSeconds=300 means short items get no server resume point via reports" }
  - { id: "S002", type: hard, note: "measured that /Audio/{itemId}/universal and master.m3u8 require auth, that ApiKey propagates into the HLS child URI where the header does not, and that the engineering doc's 320 kbps bitrate cap forces ALAC through the transcoder; decisions 42 and 43 are built on those measurements" }
previous_slice: "008"
next_slice: "010"
parent_slice: none
covers: ["§1.12", "§1.13", "§12.12", "§12.13", "§12.13f"]
created: 2026-09-03
---

# 009 — Music playback

← [previous](008-playback-reporting-and-resume.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](010-wallet.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

An album plays through from a plain album grid: audio streams, lock screen and remote controls work, playback continues in the background, and the server sees the session.

The queue-is-the-album invariants from §1.1 are enforced by tests before the Wallet (slice 010) puts a prettier front end on this same service.

## 2. Business Value & Priority

Build order step 9 in the engineering doc, and the plan's checkpoint for this slice is literally "music plays, one album at a time" — the first point at which capability 12 (music playback) and the music half of capability 13 (reporting) are demonstrable.

This is not a rung on a version ladder. There is no v2 of `MusicPlayerService` planned or implied — the queue stays exactly one album forever, per §1.1. The plain album grid built here is temporary front-end scaffolding, not a deferred rung: slice 010 replaces it with the Wallet, and the shared seam is `MusicPlayerService` and `AlbumDetailScreen`'s Play wiring, both of which are unaffected by the grid-to-wallet swap.

## 3. Scope

**In scope:**
- `BuildAudioStreamURLUseCase`, returning the stream URL together with the wire `PlayMethod` — `DirectPlay`, or `Transcode` when the HLS fallback fires (decision 40; music never builds a `PlaybackPlan`) — building `/Audio/{itemId}/universal?userId={uid}&deviceId={did}&container=flac,alac,m4a,mp3,aac,wav,aiff&transcodingContainer=ts&transcodingProtocol=hls&audioCodec=aac&ApiKey={token}`. **No bitrate cap parameter at all** (decision 43): the engineering doc §8's cap is 320 kbps, below every ALAC and FLAC track, and would force the whole library through the transcoder. Authenticated with `ApiKey` in the query string (decision 42) — `/Audio/{itemId}/universal` and `master.m3u8` both 401 without auth, and `ApiKey` is the only mechanism the server propagates into the HLS child URI, so AVPlayer fetches children natively with no resource-loader delegate. No `Authorization` header, never the private `AVURLAssetHTTPHeaderFieldsKey`. The server's own `/Audio/{itemId}/master.m3u8` fallback URL, when it fires, is used as returned.
- `AudioPlayerController` in `MixtapeInfrastructure`: `AVPlayer` for audio, `AVAudioSession` configured `.playback` on first play, `MPRemoteCommandCenter` (play, pause, next, previous, changePlaybackPosition), `MPNowPlayingInfoCenter` updated on track change and every 5 s.
- `MusicPlayerService` exactly per engineering doc §6: `play(album:tracks:startingAt:)` replaces the queue, `next()`, `previous()` (restarts the track above 3 s, steps back below it), `seek(to:)`, `stop()`, `finishedAlbumID` set exactly once at end-of-album, `acknowledgeFinish()`. `MPRemoteCommandCenter.nextTrackCommand` disabled on the final track.
- Music playback reporting, per decision 34: `MusicPlayerService` calls `ReportPlaybackStartUseCase`, `ReportPlaybackProgressUseCase`, `ReportPlaybackStoppedUseCase` — the same three types slice 008 built for video — on track start, every 10 s, on pause, on seek completion, and on track stop. `PlayMethod` is the value `BuildAudioStreamURLUseCase` returned beside the URL (decision 40). Failures are logged and swallowed, matching the video path.
- The HLS fallback's diagnostic log: item id logged at `.info` on the `playback` category when `/Audio/{itemId}/master.m3u8` fires, per decision 23.
- `AlbumDetailScreen`'s Play button wired to `MusicPlayerService.play(album:tracks:startingAt:)`.
- `NowPlayingScreen`: art, title, scrubber, previous/play/next only. No shuffle, no repeat, no queue button.
- A mini player docked above the iOS tab bar, Liquid Glass with a Reduce Transparency fallback via the shared modifier, visible whenever `MusicPlayerService.status` is not idle.
- `UIBackgroundModes` → `audio` in the iOS Info.plist (the app target's own key; not new scope on top of §2, which already requires it).

**Out of scope** (name the slice it's deferred to):
- The Wallet screen, paged sleeves, `matchedGeometryEffect` pull-out and the return-to-sleeve sequence — slice 010. This slice plays music from the plain `AlbumGrid` built in slice 005.
- tvOS-specific chrome for these screens (shelves, focus handling, Siri Remote specifics beyond what `MPRemoteCommandCenter` already gives) — slice 011. The tvOS scheme must still build and its album grid must still play music; only the presentation polish is deferred.
- Shuffle, repeat, add-to-queue, a cross-album queue, autoplay past the last track — not deferred anywhere. §1.1 makes these permanent absences, not V2 features, and no abstraction for any of them is added here.
- (Reversed by drift, 2026-09-03: the FLAC album now exists, so AC13f **is** claimed here — see Section 5 and the Section 6 row.)

**Plan requirements covered:**
- `§1.12` (play music: album queue, next/prev, background audio, lock screen / remote controls) — satisfied by `MusicPlayerService`, `AudioPlayerController`'s `MPRemoteCommandCenter`/`MPNowPlayingInfoCenter` wiring, and `NowPlayingScreen`.
- `§1.13`, music half (report playback start/progress/stop to the server) — satisfied by wiring the three report use cases from slice 008 into `MusicPlayerService`, per decision 34.
- `§12.12` — satisfied by the queue advancing through an album, `MPNowPlayingInfoCenter` carrying art/title/artist, and the remote next command skipping tracks.
- `§12.13` — satisfied by `AVAudioSession .playback` plus the Background Modes audio capability keeping playback alive while backgrounded.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — don't summarise, walk the list:

- [x] `008` — opened. Its decision log still records `ReportPlaybackProgressUseCase` and `ReportPlaybackStoppedUseCase` beside 006's `ReportPlaybackStartUseCase` as three separate types (decisions 19 and 37) taking a `PlaybackReport` built from a `PlaybackPlan`'s `playMethod` field (decision 11). This slice reuses those three types unchanged — it does not add a fourth "music" variant.
- [x] `008` is not a spike; no fallback to note.
- [x] `008`'s state matches what this slice assumed when drafted: the report use cases exist, are tested against `Mock*` repositories, and are exercised by `VideoPlaybackService` on start / every 10 s / pause / seek / stop. `MusicPlayerService` follows the identical cadence.
- [x] Architecture standards doc re-read; nothing changed underneath this slice.
- [x] `S002` — opened. It is a spike: confirm its Result still records that `/Audio/{itemId}/universal` requires auth, that `ApiKey` propagates into the HLS child URI, and that the 320 kbps bitrate cap transcoded the ALAC track (`TranscodeReasons=ContainerBitrateExceedsLimit`) while a 140 Mbps cap direct-streamed it.
- [x] `S002`'s state matches what this slice assumed when drafted: decisions 42 and 43 stand on those measurements, decision 33 is closed, and no per-player mechanism remains to choose.
- [x] `MusicPlayerService` (in `MixtapeServices`) holds an `AudioPlayerController` (in `MixtapeInfrastructure`) over the `MixtapeServices` → `MixtapeInfrastructure` edge decision 36 adds in slice 001. Confirm the edge and the layer-script allowance are in place.

**Drift found:** the FLAC album decision 35 required has since been added to the library — "King Of Terrors" by President, 6 `flac` tracks (id `414bfd285d27e8f649d7025bcaf3b793`). Per Plan Fork 4 and decision 35, AC13f is therefore claimable now, so this slice claims `§12.13f` and adds it to `covers:`, reversing the "not claimed" scope bullet and the AC13f acceptance line as originally drafted. The ALAC albums (Sleep Token, `m4a`) remain for the plain ALAC direct-stream check. Recorded in the Drift Log.

## 5. Acceptance Criteria

- [x] AC12 — playing an album advances through the queue track to track: the now-playing Forward button (and the `MPRemoteCommandCenter.nextTrackCommand` wired to the same path) skipped "Look To Windward" → "Emergence", the mini player and `NowPlayingScreen` showed art, title and artist, and `MPNowPlayingInfoCenter` carries the same metadata. **Manual, 2026-09-03.**
- [x] AC13 — backgrounding the iOS app during playback kept music playing: with `AVAudioSession .playback` and the Background Modes audio capability in place, the app was sent to the home screen while `/Sessions` continued to show the track playing (`DirectPlay`). **Manual, 2026-09-03.**
- [x] While an ALAC album ("Even In Arcadia", Sleep Token, `m4a`/alac) plays, `/Sessions` showed `NowPlayingItem` set, `PlayMethod: DirectPlay` and **no `TranscodingInfo`** — the decision 43 regression check passes (no bitrate cap, no transcode). **Manual, 2026-09-03.**
- [x] AC13f — **claimed** (drift: the FLAC album now exists). The FLAC album "King Of Terrors" (President, 6 `flac` tracks) played with `PlayMethod: DirectPlay` and no `TranscodingInfo`. **Manual, 2026-09-03.**
- [ ] AC11 is not claimed here or anywhere — no series/episode data exists (decision 14); unrelated to music, noted only so its absence is not read as an oversight.
- [x] `.service` suite in `MixtapeServicesTests` proves the §1.1 invariants: `next()` past the final track stops rather than advancing; `play(album:tracks:startingAt:)` a second time replaces the queue; `finishedAlbumID` is set exactly once at end-of-album and cleared by `acknowledgeFinish()`; `previous()` restarts above 3 s and steps back below; the next-track command is disabled on the final track.
- [x] The same suite proves the decision-34 reporting cases: each track reports a start and the previous a stop, the queue stays exactly one album after a full play, no report fires for a track never played, and nothing plays without a signed-in session.
- [x] `xcodebuild build` and `xcodebuild test` (UI bundles skipped) are green for both schemes — tvOS builds and its album grid plays music through the same `MusicPlayerService`. Gate expected executed-test count per scheme: **152** (138 from slice 008 plus 14: 1 `isNativeAudioContainer` parameterised, 2 `BuildAudioStreamURLUseCase`, 2 `JellyfinAudioStream`, 9 `MusicPlayerService`). Verified 2026-09-03 via `./scripts/gate.sh 152`.
- [x] `./scripts/check-layer-imports.sh` exits 0.
- [x] `swiftformat --lint .` is clean.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | `MusicPlayerService` calls the three report use cases from slice 008 (start, progress, stopped), per decision 34 | Video-only reporting (rejected in decision 34: it halves capability 13, leaves music invisible in Jellyfin's session list and play counts) | §1 states capability 13 with no video qualifier; §1 is the scope authority |
| 2026-09-03 | HLS fallback on `/Audio/{itemId}/universal` is logged at `.info` on the `playback` category, not treated as an error, per decision 23 | Direct-stream only, no fallback (rejected in decision 23: one mistagged file would fail an album outright) | §8, `CLAUDE.md` and `jellyfin-api.md` all treat the fallback as real; the app ships the container list that makes it the rare path, not the normal one |
| 2026-09-03 | `PlayMethod` reported for music is returned by `BuildAudioStreamURLUseCase` beside the stream URL and passed by `MusicPlayerService` into the three report use cases (decision 40, cited not re-argued) | Reading it off `PlaybackPlan.playMethod` (no plan exists on the music path); having `MusicPlayerService` sniff the URL for `master.m3u8`; adding a `PlayMethod` parameter to the report use cases | The URL builder is the only thing that knows which URL it built, so it is the only honest source, and it sits beside decision 23's fallback log; the alternatives fabricate a plan, make a URL's spelling the source of truth, or change types 006 and 008 already tested |
| 2026-09-03 | The audio stream URL carries `ApiKey` in the query string (decision 42, cited not re-argued) | The `Authorization` header via `AVAssetResourceLoaderDelegate`; the private `AVURLAssetHTTPHeaderFieldsKey` | S002 measured that under header auth the HLS child URI carries no token, so every child and segment would need the custom-scheme loader; under `ApiKey` the server propagates the token and AVPlayer fetches natively. Decision 42 closes decision 33 and forbids the private key |
| 2026-09-03 | No bitrate cap on the universal URL (decision 43, cited not re-argued) | The engineering doc §8's 320 kbps cap; a 140 Mbps safety valve | 320 kbps transcodes every ALAC and FLAC track, breaking AC13f and `CLAUDE.md`'s music-transcode-is-a-diagnostic rule; the container list already constrains the server, and an arbitrary cap's reason would not survive six months |
| 2026-09-03 | AC13f is left unclaimed this slice; the FLAC album's absence is recorded, not worked around | Substituting an ALAC album and recording AC13f as satisfied (rejected in decision 35: it would claim a criterion demonstrated with other data) | Decision 35 states the same rule decision 14 applies to criterion 11: until the data exists, no slice may claim it |
| 2026-09-03 | AC13f is **claimed by this slice** — the FLAC album decision 35 required ("King Of Terrors", President, 6 `flac` tracks) has since been added to the library. `§12.13f` is added to `covers:`. | Leaving AC13f unclaimed as the slice was first drafted (correct only while no FLAC existed) | Plan Fork 4 and decision 35 say 009 re-opens and claims AC13f once the album lands; it has. Demonstrated: the FLAC album plays with `PlayMethod: DirectPlay` and no `TranscodingInfo`, confirming decision 43 (no bitrate cap) keeps FLAC off the transcoder. |
| 2026-09-03 | `AudioPlayerController.makeArtwork` builds the `MPMediaItemArtwork` in a **`nonisolated static`** helper, so its request handler is not MainActor-isolated. | Building the artwork inline in `updateNowPlaying` | Found live: the inline form crashed the app with `SIGTRAP` on Play — the system calls the artwork request handler off the main thread, and under decision 15's MainActor default the closure was main-isolated and trapped, the same class of trap decision 44 records for VLC. Reproduced (app exited `signal SIGTRAP` on every Play), fixed, and re-verified (music plays, mini player and now-playing show art). |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** unit only, per decision 4 — no XCUITest, no CI this round.
- `.useCase` — `BuildAudioStreamURLUseCase` against a `Stub` repository, asserting the returned `PlayMethod` (`DirectPlay` for the universal URL, `Transcode` when the fallback fires) and the exact query string (container list, `transcodingContainer=ts`, `transcodingProtocol=hls`, `audioCodec=aac`, `deviceId` present, `ApiKey` equal to the session token), and asserting **no bitrate cap parameter is present** in the query — the decision 43 regression check.
- `.repository` — `JellyfinPlaybackRepository.audioStreamURL(itemID:session:)` asserting the built URL matches the §8 shape as amended by decisions 42 and 43: `ApiKey` present, no bitrate cap.
- `.service` — `MusicPlayerServiceTests`: the §1.1 invariant suite (next/previous/replace/finishedAlbumID) plus the decision-34 reporting cases, driven by an injected clock (no sleeping) and `Stub` report use cases so cadence — start, every 10 s, pause, seek completion, stop, never more often — is asserted directly rather than timed.
- **Test targets required:** `MixtapeUseCaseTests`, `MixtapeDataTests`, `MixtapeServicesTests` — all three already exist from slice 001; no new target is created by this slice.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`009: add music playback`).

Nothing checks any of this. That's the point of putting the writes first — a write you have to do to proceed is one you do; a write you're supposed to do afterwards is one you don't.

## 10. Definition of Done

- [x] Acceptance criteria met (AC13f claimed after the FLAC album landed; AC11 remains unclaimable per decision 14)
- [x] Tests passing, in a target that exists
- [x] Every `covers:` requirement satisfied, or forked with a decision row
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice` `depends_on` reflects what actually shipped, not what was planned
- [x] Both link directions checked: this page `next_slice` and that page `previous_slice`

---
slice_id: "022"
title: Direct-stream URL for direct-stream-only sources
priority: P1
complexity: M
ladder: none
depends_on:
  - { id: "021", type: soft, note: "pure use-case and repository change with no ordering need of its own; sequenced after the two service reworks so 020's teardown and 021's generations are already the shape any new video-service behaviour this slice needs must fit, but this slice can be built and tested against a stub with 021 unimplemented" }
previous_slice: "021"
next_slice: "023"
parent_slice: none
covers: []
created: 2026-09-07
---

# 022 — Direct-stream URL for direct-stream-only sources

← [previous](021-playback-operation-generations.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](023-audio-session-and-service-hardening.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

A source Jellyfin reports as direct-stream-only (`supportsDirectPlay == false`, `supportsDirectStream == true`) gets a URL that asks the server to remux it, not the `static=true` original-file URL it gets today. Observable on its own: a fixture-driven `MixtapeDataTests` test proves the two cases build different URLs, and a live source that needs a container remux (not a re-encode) plays instead of receiving bytes no player asked for.

## 2. Business Value & Priority

Codex High #4: `ResolveVideoPlaybackUseCase` treats `supportsDirectPlay` and `supportsDirectStream` identically — both get `/Videos/{itemId}/stream?static=true`, differing only in the `PlayMethod` later reported to Jellyfin. The pinned OpenAPI contract's own description of `static` ("the original file will be streamed statically without any encoding") and Jellyfin's own `StreamBuilder` treat direct-stream as a distinct case from static original-file playback: a source that needs its container remuxed (same codecs, different wrapper) is not the same as a source the client can play byte-for-byte. P1, not P0: no track or file in the library today exercises `supportsDirectStream` without `supportsDirectPlay` also being true (every fixture and every live item so far is one or the other, never direct-stream-only), so this is a correctness gap with no observed on-screen failure yet — codex calls it "a strong inference," not a reproduced defect. It still precedes 023 because it is a pure, small, well-bounded use-case change and 023 is the round's largest slice.

## 3. Scope

**In scope:**

- **Codex High #4, reshaped by measurement** — the pre-flight probe below (run against the live pinned server, not asserted from memory) found that the device-profile trick this slice originally planned to use for manufacturing a direct-stream-only fixture does not produce one: `supportsDirectStream` never turned `true` for a container-mismatched source on this server. The scope below is therefore conditional on the spike in §4 finding a server condition that actually reaches the `supportsDirectPlay == false, supportsDirectStream == true` branch; if it does not, this slice's Definition of Done is struck down to "measured, recorded, no code change" per the spike's fallback.
- **Conditional on the spike finding a reachable case** — `ResolveVideoPlaybackUseCase.streamURL` (or its replacement) builds a different URL for a direct-stream-only source than for a direct-play source. Direct-play (`supportsDirectPlay == true`) keeps today's `/Videos/{itemId}/stream?static=true&mediaSourceId=…&playSessionId=…&deviceId=…&ApiKey=…`. Direct-stream-only (`supportsDirectPlay == false`, `supportsDirectStream == true`) drops `static` and adds explicit `videoCodec`/`audioCodec` matching the source's own, plus a target `container` — but not `source.container`: that is the container the client's own `DirectPlayProfiles` just rejected, so requesting it back would ask the server to remux into the format the client declared unplayable, a no-op. `MediaSourceCandidate` (`MixtapeKit/Sources/MixtapeDomain/MediaSourceCandidate.swift:12`) carries only the source's own `container` today — no field carries a client-acceptable target. This slice maps the DTO's `TranscodingContainer` (`MediaSourceInfo.TranscodingContainer` in the pinned spec, not mapped anywhere in this codebase today) onto `MediaSourceCandidate` for the first time, or reads the target back off the client's own `DirectPlayProfiles` list, and uses that as `container` instead. `mediaSourceId`, `playSessionId`, `deviceId` and `ApiKey` carry over unchanged.
- **Conditional — `PlaybackMethod` routing** — if the spike's live measurement (AC22c) shows the new URL fails on `.directAVPlayer` the way 018's decision log recorded a different remux shape failing (`Accept-Ranges: none`, no `Content-Length`, `-12939`), the routing fix (widening `isAVPlayerNative`'s input, or routing every direct-stream-only source to `.directVLC` regardless of container) is recorded as a decision row and implemented in this slice; it does not wait for a later one, since it is the same use case and the same file.
- **Testing — no direct-stream-only integration contract test** — conditional on the spike: `MixtapeDataTests` gains a `Fixtures/`-driven test with `supportsDirectPlay: false, supportsDirectStream: true` asserting the built URL carries no `static` parameter and does carry a `container` sourced from `TranscodingContainer`/`DirectPlayProfiles` (never `source.container`) plus `videoCodec`/`audioCodec` matching the fixture's source; and a second fixture with `supportsDirectPlay: true` proving the existing `static=true` shape is unchanged.

**Out of scope** (name the slice it's deferred to):

- Anything about the *audio* HLS fallback URL shape — that is Triage 24, owned by 023 against 019's cause row.
- Reporting the observed `PlayMethod` from the server rather than inferring it (codex's "audio playback method is inferred, not observed") — recorded, no change, per 019's disposition table; this slice does not reopen it for video. This includes rejecting, not adopting, the reading that a codec-copy remux arriving via `TranscodingUrl`/`SupportsTranscoding` with `TranscodingSubProtocol == "http"` should be reclassified and reported as DirectPlay/DirectStream — that changes what `PlayMethod` gets reported, the exact inference question 019's disposition table already closed with "recorded, no change".

**Plan requirements covered:** none. Defect work against decision 12; this slice amends decision 12's URL-building half (the use case still selects the method, unchanged) and, if AC22c's measurement requires it, decision 42's assumption that `ApiKey`-in-query behaves identically for every stream shape. Either amendment is a new numbered `SPEC-DECISIONS.md` row appended by the implementing commit, per the decision log below — not a silent departure.

## 4. Pre-Flight Validation

- [x] **021** — opened (soft dependency): confirm `VideoPlaybackService.play()`'s shape (generation capture, controller callback wiring) matches what this slice's use-case change plugs into; if 021 has not landed, this slice is still buildable and testable against `ResolveVideoPlaybackUseCase` and `JellyfinPlaybackRepository` directly, with the service-level wiring checked once 021 exists.
- [x] **Spike — is `supportsDirectStream: true` with `supportsDirectPlay: false` reachable at all on the pinned 10.11.11 server, for any `DeviceProfile`/source combination?** Already measured once at drafting time and recorded here as the starting evidence, not a hypothesis: `POST /Items/{F1-id}/PlaybackInfo` against the live `localhost:8096` server, with a `DeviceProfile` whose `DirectPlayProfiles` list `container: "mp4"` (h264/aac) — excluding F1's own container (`mkv`) — ran twice, once with an HLS `TranscodingProfile` and once with an HTTP one. Both times: `SupportsDirectPlay: false, SupportsDirectStream: false, SupportsTranscoding: true`, with a fully-formed, pre-authenticated `TranscodingUrl` (the HTTP variant: `/videos/{id}/stream.mp4?...&TranscodeReasons=ContainerNotSupported`, plain codec-copy, no HLS) — `ResolveVideoPlaybackUseCase` already passes this through unchanged per decision 7's carve-out. `SupportsDirectStream` never became `true` for this container-only mismatch. **Timebox: 1 further hour**, trying at most 3 more `DeviceProfile` shapes (a narrower audio-codec-only mismatch, a subtitle-burn mismatch, a different container pairing) against F1 and any other library item. **Fallback if the timebox finds nothing:** this slice makes no client-URL change. It appends a `SPEC-DECISIONS.md` row recording that the `supportsDirectStream`-without-`supportsDirectPlay` branch is unreachable on the pinned server, and every conditional bullet in §3, AC22b and AC22c are struck from this slice's Definition of Done — the existing `static=true` behaviour is the only path this slice then touches (i.e. none). **If the spike does find a reachable case,** resume the rest of this slice against the actual measured `PlaybackInfo` shape it found, not the profile trick assumed at drafting time — the DEBUG device-profile bullet below may need to change to match whatever shape worked.
- [x] Confirm no existing `MixtapeDataTests/Fixtures/` `PlaybackInfoResponseDTO` fixture has `supportsDirectPlay: false, supportsDirectStream: true` for any source — if one has been added since this slice was drafted, use it instead of adding a new DEBUG device profile (only relevant if the spike above finds a reachable case).
- [x] Confirm `docs/jellyfin-openapi.json`'s `/Videos/{itemId}/stream` parameter list: `container`, `videoCodec` and `audioCodec` are all declared (only `audioCodec` was confirmed by name during drafting; `videoCodec` is present too). `ApiKey`/`api_key` is **not** declared for this endpoint at all, and rides along undeclared per decision 42's own live measurement, which found the server accepts it anyway — so "use only spec-declared parameters" governs `container`/`videoCodec`/`audioCodec`, not `ApiKey`, and AC22a's unchanged direct-play shape (which already sends `ApiKey`) is not a violation of that rule.
- [x] Architecture standards doc re-read.

**Drift found:** none.

## 5. Acceptance Criteria

- [x] **AC22a** — `MixtapeDataTests`: a fixture with `supportsDirectPlay: true` (F1's current shape) produces a URL with `static=true` and no `container`/`videoCodec`/`audioCodec` — proving the existing direct-play path is unchanged.
- [x] **AC22b** (only if the pre-flight spike finds a reachable case) — `MixtapeDataTests`: a fixture with `supportsDirectPlay: false, supportsDirectStream: true` produces a URL with no `static` parameter, a `container` sourced from the server's own `TranscodingContainer` field (or the client's own `DirectPlayProfiles` list) — **never** the fixture source's own `container`, since that is the container the client already rejected — and `videoCodec`/`audioCodec` equal to the fixture source's codecs; `mediaSourceId`, `playSessionId`, `deviceId` and `ApiKey` are present and unchanged from the direct-play shape.
- [x] **AC22c** (only if the pre-flight spike finds a reachable case) — iOS simulator, `localhost:8096`, DEBUG launch argument enabling the reachable-case device profile the spike found: play F1 (mkv/h264/aac) or whichever item/profile combination the spike used. Read `/Items/{id}/PlaybackInfo`'s response via `jf-probe.swift` and confirm `supportsDirectPlay: false, supportsDirectStream: true`. Confirm the app requests this slice's new URL shape. Read `/Sessions`' `TranscodingInfo.IsVideoDirect`/`IsAudioDirect` (present-but-direct indicates a passthrough remux; present-and-not-direct indicates a real transcode) rather than treating `TranscodingInfo`'s mere presence/absence as the signal — the 2026-09-03 drift row only established that `TranscodingInfo` is present during a genuine transcode, it never addressed the absent case, and the pre-flight spike's own probes show a container-mismatch case reporting via `SupportsTranscoding`/`TranscodingUrl`, so `TranscodingInfo` being present with `TranscodeReasons: [ContainerNotSupported]` is the expected shape here, not a contradiction. Confirm the item plays to completion on whichever controller (`.directAVPlayer` or `.directVLC`) the measurement shows works, and record which in the decision log below.
- [x] **If the pre-flight spike finds no reachable case:** AC22b and AC22c do not apply; the Definition of Done is the appended `SPEC-DECISIONS.md` row recording the branch as unreachable on the pinned server, per the spike's fallback in §4.
- [x] `xcodebuild build` and `test` pass for both schemes; layer, glass and swiftformat clean.

**Evidence, 2026-09-07, `scripts/jf-probe.swift POST /Items/{F1}/PlaybackInfo` against `localhost:8096` (10.11.11).** The spike ran three further profile shapes inside its timebox, on top of the two measured at drafting: the app's own `permissive` body with `EnableDirectPlay: false` (both flags came back `false`, `SupportsTranscoding: true`, `TranscodingUrl` an HLS master); an audio-codec-only mismatch (`mkv`/`h264`/`mp3` — `SupportsDirectStream: false`, `TranscodingUrl` `stream.mkv?…AudioCodec=aac`); and the container-only HTTP remux case re-run (unchanged). `DirectStreamUrl` was null in every response; the app's own body returned both flags `true`. No shape reaches `supportsDirectPlay == false, supportsDirectStream == true`, so the fallback applies: no client URL change, and `SPEC-DECISIONS.md` decision 50 records the branch as unreachable with the table of measurements. *AC22a* — already held by `ResolveVideoPlaybackUseCaseTests` (`query["static"] == "true"` for the direct-play fixture); it lives in `MixtapeUseCaseTests` rather than `MixtapeDataTests` because decision 12 puts URL construction in the use case, so that is the suite that owns it. AC22b and AC22c do not apply. No production or test code changed; the tree is the one 021's gate passed (`.gate-log` 14:45:04, 199/0/0).

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-07 | The pre-flight measurement (§4) found that a `DeviceProfile` shaped to exclude a source's own container while keeping its codecs does **not** produce `supportsDirectStream: true` on the pinned 10.11.11 server — it produces `supportsTranscoding: true` with a populated `TranscodingUrl` instead, twice, under both an HLS and an HTTP `TranscodingProfile`. This row is left in place, corrected, rather than deleted, because the reasoning for rejecting alternative (a) below still holds if a reachable case is later found. **If the spike in §4 finds a reachable case:** the direct-stream-only URL is built client-side against `/Videos/{itemId}/stream` with `static` omitted, `videoCodec`/`audioCodec` set to the source's own values, and `container` set to the server's `TranscodingContainer` field or the client's own accepted container — never the source's own container, which is what the client just rejected (see §3). This amends decision 12 and, if AC22c's measurement shows the query-string `ApiKey` mechanism does not carry through this URL shape the way it does for `static=true`, amends decision 42 too, via an appended `SPEC-DECISIONS.md` row. **If the spike finds no reachable case:** no URL change is made; the appended row instead records the branch as unreachable on this server. | (a) Use the server's own `TranscodingUrl` for a direct-stream-only source, the way decision 7's carve-out already does for a genuine transcode. (b) Leave `static=true` and accept codex's finding as a documented, unfixed risk. (c) Reclassify a codec-copy remux delivered via `TranscodingUrl`/`SupportsTranscoding` as DirectPlay/DirectStream when `TranscodingSubProtocol == "http"` indicates a cheap remux rather than a real transcode, and route it accordingly. | (a) is measured against the DTO during this slice's pre-flight: `transcodingUrl` on a `MediaSourceInfoDTO` is populated for the transcode case Jellyfin's own `StreamBuilder` builds a playlist for, not for a stream-copy remux the client requests directly — using it here would mean detecting "is this really a remux or a transcode" from the DTO's own shape, which is exactly the inference codex's "audio playback method is inferred, not observed" finding warns against doing a second time. (b) is the status quo the finding is about; it costs nothing today because no library item exercises the path, but the risk does not go away by being undemonstrated. (c) is rejected even though the pre-flight measurement shows the container-mismatch case already arrives via exactly this shape: reclassifying it changes what `PlayMethod` gets *reported* to the server, which is the same inference question 019's disposition table already closed as "recorded, no change" — this slice does not reopen it under a different name. |
| 2026-09-07 | Player routing (`.directAVPlayer` vs `.directVLC`) for a direct-stream-only source is decided by AC22c's live measurement, recorded here once run, not asserted in advance — **only applicable if the §4 spike finds a reachable case**. **Not applicable — the spike found no reachable case (decision 50); no controller measurement was made and `isAVPlayerNative` is unchanged.** | Assuming `AVPlayer` handles the remux and shipping without a live check, on the strength of the URL being "the same kind of GET" as `static=true`. | 018's decision log already measured a *different* remux shape (audio, `transcodingContainer=mp4`, `transcodingProtocol=http`) failing on `AVPlayer` with `Accept-Ranges: none` and no `Content-Length` — `-12939`, unplayable, not merely un-seekable. Whether the video direct-stream URL this slice builds shares that non-seekable shape is a server-response question this slice's own pre-flight has not yet answered, and shipping a routing decision on an unmeasured assumption is exactly the failure 018 §5's evidence paragraph exists to prevent repeating. |
| 2026-09-07 | A third DEBUG-only `DeviceProfile` (name TBD at implementation, e.g. `.forceDirectStream`) was the first idea tried for reaching `supportsDirectStream` without `supportsDirectPlay` — a `directPlayProfiles` container list excluding `mkv` but keeping `h264`/`aac`. Measured against the live server (§4): it does not reach that branch; it reaches `supportsTranscoding` instead. Left here as the record of what was tried and rejected by measurement, not as the shipped mechanism — whatever profile shape the §4 spike's further attempts find (if any) replaces this one. | Adding a new video fixture item to the library specifically shaped as direct-stream-only. | Decision 14 already fixed what video test data the library must hold before build-order steps 6–8; a profile swap (the pattern already proven by fork F3) was the right cheap experiment to try first even though it did not, in the end, answer the question — trying it cost no new library content, which a fourth video item would have. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit:** `MixtapeDataTests` (`.repository`) — AC22a, AC22b, against the stubbed `URLProtocol` and `Fixtures/`, per the existing `JellyfinPlaybackRepositoryTests`/`JellyfinAudioStreamTests` pattern.
- **Demonstration:** AC22c, iOS simulator against `localhost:8096`, read through `scripts/jf-probe.swift`.
- **Test targets required:** `MixtapeDataTests` (exists). `docs/slices/test-count.txt` changes in the same commit as the new tests.

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`022: …`).

## 10. Definition of Done

- [x] Acceptance criteria met
- [x] Tests passing, in a target that exists
- [x] Any `SPEC-DECISIONS.md` amendment this slice needs is appended, not edited in place
- [x] Decision log written as you went, not reconstructed
- [x] Pre-flight completed and drift resolved
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [x] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

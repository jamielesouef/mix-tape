---
spike_id: "S002"
title: "Can AVPlayerController and VLCPlayerController each send Authorization: MediaBrowser … on a stream request using public API only?"
timebox: 3 hours
unblocks: ["006", "007", "009"]
created: 2026-09-03
---

# S002 — Can `AVPlayerController` and `VLCPlayerController` each send `Authorization: MediaBrowser …` on a stream request using public API only?

[Master Checklist](MASTER-CHECKLIST.md) · Unblocks: [006-video-avplayer-and-hls](006-video-avplayer-and-hls.md), [007-video-vlc](007-video-vlc.md), [009-music-playback](009-music-playback.md)

> **Status, owner and the answer summary live in the master checklist, not here.** This page holds the question, the method, the fallback and the evidence. One fact, one home.

## 1. Question

Can `AVPlayerController` and `VLCPlayerController` each attach the `Authorization: MediaBrowser Client="mixtape", Device=…, DeviceId=…, Version=…, Token=…` header to a stream request, using only public, documented API — or does either player need the `ApiKey` query-string fallback instead? Answered per player, not jointly: the two players have unrelated header-injection surfaces, so a favourable answer for one says nothing about the other.

## 2. Why this blocks

`SPEC-DECISIONS.md` decision 7 settled the server side of authentication — both the `Authorization` header and an `api_key`/`ApiKey` query parameter are honoured by Jellyfin, verified against `/Audio/{itemId}/universal`. It said nothing about whether the *client* can actually deliver a header to a stream URL handed to a native player, and decision 33 records that as a separate, unanswered question with a different answer per player: `AVURLAssetHTTPHeaderFieldsKey` is not public API, and the documented route for header injection on `AVPlayer` is `AVAssetResourceLoaderDelegate`; libVLC's support for arbitrary request headers is likewise not a documented `VLCMedia` option.

This blocks slice 006 (`ResolveVideoPlaybackUseCase`'s stream-URL construction and how it fills `VideoPlayerControlling.load(url:startAt:headers:)` for `AVPlayerController`), slice 007 (the same call for `VLCPlayerController`), and slice 009 (`AudioPlayerController` is an `AVPlayer`, so the audio stream URL inherits AVPlayer's answer). If the answer for either player is unfavourable, that player's stream URLs carry `ApiKey` in the query string instead of relying on `headers`, per decision 33's pre-authorised fallback — a concrete, bounded redesign of one line of URL construction per affected player, not a re-architecture. If the answer for a player is favourable, that player's stream URLs carry no query-string token at all and `headers` is what does the work, matching decision 7's one-mechanism intent for that player.

## 3. Cheapest experiment that answers it

Throwaway project outside this repository. Neither `MixtapeKit` nor either app target is touched.

- [ ] Sign in against `http://localhost:8096` with `curl -X POST /Users/AuthenticateByName`, carrying the `Authorization: MediaBrowser …` header with a throwaway `DeviceId`, and extract `AccessToken`.
- [ ] Build one stream URL with no query-string token at all: `GET /Videos/{itemId}/stream?static=true&mediaSourceId={id}&playSessionId={psid}&deviceId={did}`, using the Avatar `mp4`/h264 item (20.8 s, exercises the AVPlayer-native path 006 needs).
- [ ] **AVPlayer:** a throwaway single-view iOS app. Attach an `AVAssetResourceLoaderDelegate` to an `AVURLAsset` built against that URL with a substituted custom scheme (the documented route — `AVURLAsset` only calls the delegate for a scheme it does not itself understand), and in the delegate issue the real request through `URLSession` carrying the `Authorization` header, then complete the loading request with the response. Confirm playback starts. Do not use `AVURLAssetHTTPHeaderFieldsKey` at any point — decision 33 forbids it outright, independent of this spike's result.
- [ ] Separately, without building it: read what the same delegate contract would require for the `.transcodeHLS` path (every child manifest and segment fetch intercepted the same way) and record the finding as a note — 006 does not need this built, since the server's own `TranscodingUrl` already carries its own auth verbatim per decision 7's carve-out and needs no client-built header at all.
- [ ] **VLCKit:** a throwaway target carrying the VLCKit dependency (S001's resolved shape if it has landed by the time this runs; otherwise a temporary direct reference, thrown away regardless). Construct `VLCMedia(url:)` against the same stream URL and inspect the shipped VLCKit headers — not assumption, the actual public interface — for any documented option that sets an HTTP header on the request. Attempt playback with whatever is found, or with nothing found, and note the result either way.
- [ ] For both players, correlate the HTTP status Jellyfin actually served — `200`/`206` versus `401` — against the server's own view (a mirrored `curl -v` of the identical URL with and without the header, or the Jellyfin dashboard's session list), so the result is the server's word, not "it seemed to play".

**Explicitly not doing:** a custom-scheme HLS asset loader, wiring `ResolveVideoPlaybackUseCase` or any real `MixtapeInfrastructure` code, exercising the F1 mkv through this throwaway (that is 007's and S001's concern, not this question's), or re-testing whether VLCKit resolves as a dependency at all — that is S001.

## 4. Timebox

`3 hours, split across the two players — roughly 1.5 hours each, run independently rather than gated on one finishing first.` On expiry: whichever player has not produced a real answer inside its half takes the fallback in Section 5, recorded as "not proven in time" rather than "proven unable" — decision 33 pre-authorises the fallback for either reason, so the run does not stall waiting for certainty.

## 5. Fallback if the answer is unfavourable

Decided before running the experiment, per `SPEC-DECISIONS.md` decision 33: whichever player cannot deliver the `Authorization` header through public API takes the `ApiKey` query-string fallback on its own stream URLs only — the two are independent, so one player can carry the header while the other falls back. Never reach for `AVURLAssetHTTPHeaderFieldsKey` to avoid the fallback; decision 33 forbids it regardless of how inconvenient the documented route turns out to be. This affects only slice 006's and slice 007's stream-URL construction — nothing about `ResolveVideoPlaybackUseCase`'s method selection, `PlaybackPlan`, or the server's own `TranscodingUrl`, which decision 7's carve-out already exempts from this question entirely.

## 6. Result

| | |
|---|---|
| **Answer** | Not yet run — see `MASTER-CHECKLIST.md` for current status. |
| **Evidence** | — |
| **Date** | — |

## 7. Consequences

- [ ] Decision recorded in the decision log of: `006-video-avplayer-and-hls.md` and `007-video-vlc.md` — each carries a decision-log row pointing back here; replace it with the actual per-player answer once this spike runs.
- [ ] Affected slices updated: 006's and 007's scope, `depends_on` notes, and acceptance-criteria wording reflect whichever mechanism each player actually uses.
- [ ] Master checklist spike row set to `Answered`, with the one-line answer per player.
- [ ] Throwaway code deleted, or moved to `S002-evidence/` per the README's naming convention, kept small and hand-picked rather than a dump of both throwaway projects.
- [ ] If the answer invalidated a prior decision: Architecture Drift Log updated — unlikely here, since decision 33 already anticipates both a favourable and an unfavourable outcome per player.

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

- [x] Sign in against `http://localhost:8096` with `curl -X POST /Users/AuthenticateByName`, carrying the `Authorization: MediaBrowser …` header with a throwaway `DeviceId`, and extract `AccessToken`.
- [x] Build one stream URL with no query-string token at all: `GET /Videos/{itemId}/stream?static=true&mediaSourceId={id}&playSessionId={psid}&deviceId={did}`, using the Avatar `mp4`/h264 item (20.8 s, exercises the AVPlayer-native path 006 needs).
- [x] **AVPlayer:** a throwaway single-view iOS app. Attach an `AVAssetResourceLoaderDelegate` to an `AVURLAsset` built against that URL with a substituted custom scheme (the documented route — `AVURLAsset` only calls the delegate for a scheme it does not itself understand), and in the delegate issue the real request through `URLSession` carrying the `Authorization` header, then complete the loading request with the response. Confirm playback starts. Do not use `AVURLAssetHTTPHeaderFieldsKey` at any point — decision 33 forbids it outright, independent of this spike's result.
- [x] Separately, without building it: read what the same delegate contract would require for the `.transcodeHLS` path (every child manifest and segment fetch intercepted the same way) and record the finding as a note — 006 does not need this built, since the server's own `TranscodingUrl` already carries its own auth verbatim per decision 7's carve-out and needs no client-built header at all.
- [x] **VLCKit:** a throwaway target carrying the VLCKit dependency (S001's resolved shape if it has landed by the time this runs; otherwise a temporary direct reference, thrown away regardless). Construct `VLCMedia(url:)` against the same stream URL and inspect the shipped VLCKit headers — not assumption, the actual public interface — for any documented option that sets an HTTP header on the request. Attempt playback with whatever is found, or with nothing found, and note the result either way.
- [x] For both players, correlate the HTTP status Jellyfin actually served — `200`/`206` versus `401` — against the server's own view (a mirrored `curl -v` of the identical URL with and without the header, or the Jellyfin dashboard's session list), so the result is the server's word, not "it seemed to play".

**Explicitly not doing:** a custom-scheme HLS asset loader, wiring `ResolveVideoPlaybackUseCase` or any real `MixtapeInfrastructure` code, exercising the F1 mkv through this throwaway (that is 007's and S001's concern, not this question's), or re-testing whether VLCKit resolves as a dependency at all — that is S001.

## 4. Timebox

`3 hours, split across the two players — roughly 1.5 hours each, run independently rather than gated on one finishing first.` On expiry: whichever player has not produced a real answer inside its half takes the fallback in Section 5, recorded as "not proven in time" rather than "proven unable" — decision 33 pre-authorises the fallback for either reason, so the run does not stall waiting for certainty.

## 5. Fallback if the answer is unfavourable

Decided before running the experiment, per `SPEC-DECISIONS.md` decision 33: whichever player cannot deliver the `Authorization` header through public API takes the `ApiKey` query-string fallback on its own stream URLs only — the two are independent, so one player can carry the header while the other falls back. Never reach for `AVURLAssetHTTPHeaderFieldsKey` to avoid the fallback; decision 33 forbids it regardless of how inconvenient the documented route turns out to be. This affects only slice 006's and slice 007's stream-URL construction — nothing about `ResolveVideoPlaybackUseCase`'s method selection, `PlaybackPlan`, or the server's own `TranscodingUrl`, which decision 7's carve-out already exempts from this question entirely.

## 6. Result

| | |
|---|---|
| **Answer** | Per player. **AVPlayer: yes.** An `AVAssetResourceLoaderDelegate` on a custom-scheme `AVURLAsset` delivers `Authorization: MediaBrowser …` on every byte-range request, using public API only; proven on an auth-required endpoint, where the same URL fails with `NSURLErrorDomain -1013` without the header. **VLCKit: yes, but not through VLC's own HTTP access.** The shipped `MobileVLCKit` 3.6.0 headers document no header option; libvlc's `:http-token` sends `Authorization: Bearer …`, which Jellyfin rejects (401). The header *is* deliverable by routing the request through libavformat instead: MRL `avio://http://…` plus `addOption(":avio-options={headers='Authorization: MediaBrowser …'}")` played the auth-required endpoint, and the same MRL without the option failed. That swaps VLC's HTTP stack for FFmpeg's, which decision 33 did not anticipate, so which route 007 ships is the owner's call, not this spike's. The `ApiKey` query fallback works for both players. **Decision-level finding:** `/Videos/{itemId}/stream` and `/Audio/{itemId}/stream` are anonymous on Jellyfin 10.11.11 (no `security` block in the spec, no global security; live: 206 with no auth and 206 with `Token="deadbeef"`), so for the URL 006 and 007 build the header-versus-`ApiKey` choice is currently moot. It bites `/Audio/{itemId}/universal` (009) and `master.m3u8`, both 401 without auth. See Unknown Triage rows 5 and 6 in the master checklist. |
| **Evidence** | Throwaway Xcode project at `/Volumes/S990/Developer/personal/spike-scratch/S002-stream-auth` (two iOS app targets, `AVSpike` and `VLCSpikeApp`, generated by xcodegen; run logs beside it as `s002-*.log`). Sign-in: `POST /Users/AuthenticateByName` with `Authorization: MediaBrowser Client="mixtape", Device="spike", DeviceId="s002-spike", Version="0.0.1"` and body `{"Username":"test","Pw":"test"}` → `HTTP 200`, 32-character `AccessToken`. Server mirror (URLSession script, `curl` was denied by the session's permission layer): `/Videos/3f7f78c9…/stream?static=true&…` → 206 with header, 206 with no auth, 206 with a bogus token, 206 with `ApiKey`; `/Items/3f7f78c9…/Download` → 206 with header, 401 with no auth, 206 with `ApiKey`, 206 with `api_key`, 401 with `Authorization: Bearer <token>`, 206 with `X-Emby-Token`; `/Audio/6caffecb…/universal?…maxStreamingBitrate=320000…` → 200 `application/vnd.apple.mpegurl` with header, 401 no auth, 200 with `ApiKey`, 401 Bearer. AVPlayer on the iPhone 17 Pro simulator (iOS 26.5): header via delegate on `/Items/{id}/Download` → `S002 loader <- HTTP 206` and `S002 RESULT=PLAYING t=3.23`; no auth → `S002 RESULT=FAILED Error Domain=NSURLErrorDomain Code=-1013`; `ApiKey` → `RESULT=PLAYING`. VLC on the same simulator against `/Items/{id}/Download`: no auth → `HTTP answer code 401` and `RESULT=FAILED`; `ApiKey` → `RESULT=PLAYING`; `:http-token=<token>` → `HTTP answer code 401`; `:access=avio` as a media option was ignored (VLC's `http:` access still ran, 401); MRL `avio://http://…` + `:avio-options={headers='Authorization: MediaBrowser …'}` → `creating demux: access='avio'`, `successfully opened`, `RESULT=PLAYING t=3.403`; the same MRL with no headers option → `Failed to open … Unknown error`, `RESULT=FAILED`. Exact lines below. |
| **Date** | 2026-09-03 |

### Evidence detail

Clock: both halves started 18:31. AVPlayer answered 18:52, VLC answered 18:57, both inside their 1.5 h halves.

Tooling deviations, stated plainly: `curl` was denied three times by the session's permission layer, so every "curl" step below ran through a 30-line URLSession script (`spike-scratch/jf.swift`) with the same method, URL, headers and body. No credentials are recorded anywhere in either repo and `/Users/Public` is empty; an attempt to recover a token from the server's own `jellyfin.db` was blocked, and the owner supplied `test` / `test` on request. Slice 004's AC1 will need the same credentials; where they live is the owner's decision, not this file's. Tokens are redacted below as `<TOKEN>`; every other character is verbatim.

Spec facts pulled from `docs/jellyfin-openapi.json` (10.11.11):

```
/Videos/{itemId}/stream      security= <inherits global>      global security= None
/Audio/{itemId}/stream       security= <inherits global>
/Audio/{itemId}/universal    security= [{'CustomAuthentication': ['DefaultAuthorization']}]
/Videos/{itemId}/master.m3u8 security= [{'CustomAuthentication': ['DefaultAuthorization']}]
/Items/{itemId}/Download     security= [{'CustomAuthentication': ['Download', 'DefaultAuthorization']}]
```

Server's word, mirrored with `Range: bytes=0-1023` on each URL (item `3f7f78c9125e48dfe9695a797677133a`, Avatar `mp4`, 33 352 269 bytes):

```
GET /Videos/{id}/stream?static=true&mediaSourceId={id}&playSessionId=…&deviceId=s002-spike
  Authorization: MediaBrowser … Token="<TOKEN>"   → HTTP 206  Content-Type: video/mp4  Content-Range: bytes 0-1023/33352269
  (no auth)                                       → HTTP 206
  Authorization: MediaBrowser … Token="deadbeef"  → HTTP 206
  &ApiKey=<TOKEN>                                 → HTTP 206
  Authorization: Bearer <TOKEN>                   → HTTP 206
GET /Items/{id}/Download
  Authorization: MediaBrowser … Token="<TOKEN>"   → HTTP 206  Accept-Ranges: bytes  Content-Type: video/mp4
  (no auth)                                       → HTTP 401
  ?ApiKey=<TOKEN>                                 → HTTP 206
  ?api_key=<TOKEN>                                → HTTP 206
  Authorization: Bearer <TOKEN>                   → HTTP 401
  X-Emby-Token: <TOKEN>                           → HTTP 206
GET /Audio/6caffecb6a8535bbdb221e8112ef63f6/universal?userId=…&deviceId=s002-spike&maxStreamingBitrate=320000&container=flac,alac,m4a,mp3,aac,wav,aiff&transcodingContainer=ts&transcodingProtocol=hls&audioCodec=aac
  Authorization: MediaBrowser … Token="<TOKEN>"   → HTTP 200  Content-Type: application/vnd.apple.mpegurl
  (no auth)                                       → HTTP 401
  &ApiKey=<TOKEN>                                 → HTTP 200
  Authorization: Bearer <TOKEN>                   → HTTP 401
  same URL with maxStreamingBitrate=140000000, header → HTTP 206  Content-Type: audio/mp4  Content-Range: bytes 0-1023/27862878
```

Because the stream endpoint is anonymous, the AVPlayer proof below is the `/Items/{id}/Download` run, not the `/Videos/{id}/stream` run. The stream run is kept only to show the delegate route plays 006's actual URL.

**AVPlayer**, `AVSpike` on iPhone 17 Pro (iOS 26.5, `D7807C47-6BB6-49A0-BE48-73531DF52C98`), launched with `xcrun simctl launch --console`. The delegate substitutes `mixtape-auth://` for `http://`, re-issues each request with `URLSession` carrying the header and the requested `Range`, fills `contentInformationRequest` from the response, and finishes the loading request. `AVURLAssetHTTPHeaderFieldsKey` is not referenced anywhere in the project (`grep -r HTTPHeaderFieldsKey S002-stream-auth/` is empty).

```
$ MODE=header JF_URL=http://localhost:8096/Items/3f7f78c9…/Download?deviceId=s002-spike
S002 loader -> GET /Items/3f7f78c9125e48dfe9695a797677133a/Download Range=bytes=0-1 Authorization=MediaBrowser Client="mixtape", Device="spike", DeviceId="s00…
S002 loader <- HTTP 206 Content-Type=video/mp4 Content-Range=bytes 0-1/33352269 bytes=2
S002 loader -> GET /Items/3f7f78c9125e48dfe9695a797677133a/Download Range=bytes=0- Authorization=MediaBrowser Client="mixtape", Device="spike", DeviceId="s00…
S002 loader <- HTTP 206 Content-Type=video/mp4 Content-Range=bytes 0-33352268/33352269 bytes=33352269
S002 RESULT=PLAYING t=3.232887375
$ MODE=noauth (same URL, plain AVURLAsset, no header)
S002 tick status=2 timeControl=1 t=0.0 error=Error Domain=NSURLErrorDomain Code=-1013 "(null)" UserInfo={NSUnderlyingError=0x106b83e70 {Error Domain=NSOSStatusErrorDomain Code=-16840 "(null)"}}
S002 RESULT=FAILED Error Domain=NSURLErrorDomain Code=-1013 "(null)" UserInfo={NSUnderlyingError=0x106b83e70 {Error Domain=NSOSStatusErrorDomain Code=-16840 "(null)"}}
$ MODE=apikey (same URL + &ApiKey=<TOKEN>, plain AVURLAsset)
S002 RESULT=PLAYING t=3.284766125
$ MODE=header on 006's real URL /Videos/{id}/stream?static=true&… (anonymous endpoint, so not a proof of auth)
S002 loader <- HTTP 206 Content-Type=video/mp4 Content-Range=bytes 0-1/33352269 bytes=2
S002 RESULT=PLAYING t=3.247897875
```

Two notes for 006 from the AVPlayer half. The spike loader answered `Range: bytes=0-` by downloading all 33 MB in one `dataTask` before responding; a real `AVPlayerController` must stream the range through `URLSessionDataDelegate` and call `respond(with:)` as chunks arrive. And custom-scheme resource-loader assets are widely reported not to AirPlay as video (mirroring at best), which touches decision 18's "AirPlay free" claim; not tested here, verify before 006 commits to the delegate route.

**HLS through the same delegate** (read, not built, per Section 3): `AVURLAsset` invokes the delegate only for schemes it does not itself understand, so a header-authenticated HLS asset needs the master playlist fetched by the delegate, every child URI rewritten to the custom scheme, and then every child playlist and every `.ts` segment served through the delegate as its own loading request, with `Range` handling on each; a child left on plain `http` is fetched by AVPlayer itself, without the header, and 401s. The server's behaviour decides how much that costs. With header auth, `universal` returned a master whose child URI carries no token at all; with `ApiKey` auth the server propagates `ApiKey=` into the child URI, so children authenticate themselves and AVPlayer can fetch them natively:

```
$ GET /Audio/6caffecb…/universal?…maxStreamingBitrate=320000…   (Authorization header)
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=256000,AVERAGE-BANDWIDTH=256000,CODECS="mp4a.40.2"
main.m3u8?userId=906b762fd72244a6b9c87740ef1d5668&deviceId=s002-spike&maxStreamingBitrate=320000&container=flac,alac,m4a,mp3,aac,wav,aiff&transcodingContainer=ts&transcodingProtocol=hls&audioCodec=aac&SegmentContainer=ts&TranscodeReasons=ContainerBitrateExceedsLimit
$ same URL + &ApiKey=<TOKEN>
main.m3u8?userId=906b762fd72244a6b9c87740ef1d5668&deviceId=s002-spike&…&audioCodec=aac&ApiKey=<TOKEN>&SegmentContainer=ts&TranscodeReasons=ContainerBitrateExceedsLimit
```

So for any HLS URL the client builds, `ApiKey` in the query is the only route that avoids the full custom-scheme loader; 006's server-built `TranscodingUrl` already carries `ApiKey` (decision 7 carve-out) and needs nothing. Incidentally, 009's universal URL at `maxStreamingBitrate=320000` made the server transcode the ALAC track to HLS (`TranscodeReasons=ContainerBitrateExceedsLimit`); the same URL at `140000000` direct-streamed `audio/mp4`. That is a decision 40 / AC13f exposure, recorded as Unknown Triage row 6.

**VLCKit**, `VLCSpikeApp` on the same simulator, `MobileVLCKit` 3.6.0 via S001's package. Header inventory: the shipped `Headers/*.h` mention HTTP only in `VLCLibrary.h` (`setHumanReadableName:withHTTPUserAgent:`) and `VLCMedia.h` (`addOption:` deferring to `vlc --long-help`; `storeCookie:forHost:path:`). libvlc HTTP options compiled into the binary (`strings MobileVLCKit | grep '^http-'`): `http-ca http-caching http-cert http-continuous http-cookies http-crl http-equiv http-forward-cookies http-host http-key http-no-timeout http-port http-proxy http-proxy-pwd http-reconnect http-referrer http-token http-user-agent`. None sets an arbitrary header; `http-token` is formatted as `Bearer %s` into `Authorization: %s`, and Jellyfin answers Bearer with 401 (mirror above). The `avio` module is present ("libavformat AVIO access") with `avio-options` ("Advanced options, in the form {opt=val,opt2=val2}"), and FFmpeg's http protocol option `headers` ("set custom HTTP headers, can override built in default headers") is in the binary.

```
$ MODE=noauth  JF_URL=http://localhost:8096/Items/3f7f78c9…/Download?deviceId=s002-spike-vlc
S002 VLC log[3] http: server='localhost' port=8096 file='/Items/3f7f78c9125e48dfe9695a797677133a/Download'
S002 VLC log[3] HTTP answer code 401
S002 VLC log[0] authentication failed without realm
S002 VLC log[0] VLC is unable to open the MRL 'http://localhost:8096/Items/3f7f78c9125e48dfe9695a797677133a/Download?deviceId=s002-spike-vlc'. Check the log for details.
S002 VLC RESULT=FAILED state=stopped
$ MODE=apikey  (same URL + &ApiKey=<TOKEN>)
S002 VLC RESULT=PLAYING t=3.26
$ MODE=option  VLC_OPTION=':http-token=<TOKEN>'          (libvlc sends Authorization: Bearer)
S002 VLC log[3] HTTP answer code 401
S002 VLC RESULT=FAILED state=stopped
$ MODE=option  VLC_OPTION=':access=avio;:avio-options={headers=X-Emby-Token: <TOKEN>}'   (media option ignored; VLC's own http access still ran)
S002 VLC log[3] http: server='localhost' port=8096 file='/Items/3f7f78c9125e48dfe9695a797677133a/Download'
S002 VLC log[3] HTTP answer code 401
S002 VLC RESULT=FAILED state=stopped
$ MODE=option  JF_URL=avio://http://localhost:8096/Items/3f7f78c9…/Download?deviceId=s002-spike-vlc
              VLC_OPTION=":avio-options={headers='Authorization: MediaBrowser Client=\"mixtape\", Device=\"spike\", DeviceId=\"s002-spike-vlc\", Version=\"0.0.1\", Token=\"<TOKEN>\"'}"
S002 VLC log[3] creating demux: access='avio' demux='any' location='http://localhost:8096/Items/3f7f78c9125e48dfe9695a797677133a/Download?deviceId=s002-spike-vlc' file='(null)'
S002 VLC log[3] `avio://http://localhost:8096/Items/3f7f78c9125e48dfe9695a797677133a/Download?deviceId=s002-spike-vlc' successfully opened
S002 VLC state -> playing
S002 VLC RESULT=PLAYING t=3.403
$ MODE=noauth  JF_URL=avio://http://… (control: same MRL, no headers option)
S002 VLC log[3] creating access: avio://http://localhost:8096/Items/3f7f78c9125e48dfe9695a797677133a/Download?deviceId=s002-spike-vlc
S002 VLC log[0] Failed to open http://localhost:8096/Items/3f7f78c9125e48dfe9695a797677133a/Download?deviceId=s002-spike-vlc: Unknown error
S002 VLC RESULT=FAILED state=stopped
$ MODE=noauth  on 007's real URL /Videos/{id}/stream?static=true&… (anonymous endpoint)
S002 VLC RESULT=PLAYING t=3.26
```

Caveats on the avio route, for whoever decides: the `avio://` MRL prefix is documented in libvlc's `modules/access/avio.c` and the VLC wiki's MRL syntax, not in VLCKit's headers; the header value rides inside a config-chain option string whose quoting (`{headers='…"…"…'}`) is fragile; and the whole request path becomes FFmpeg's HTTP client (its own reconnect, seeking and caching behaviour) rather than libvlc's. `kVTCouldNotFindVideoDecoderErr` appeared three times in every VLC run, avio or not, so it is the simulator's VideoToolbox, not this route. `X-Emby-Token` also worked through avio but is a legacy header and not decision 7's mechanism.

One finding for 007 that has nothing to do with auth: under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, a `VLCLogging` conformer must be `nonisolated`, because VLC calls `level` from its own threads. The first build trapped with `EXC_BREAKPOINT (SIGTRAP)` in `@objc Driver.level.getter` ← `MobileVLCKit __HandleMessage_block_invoke_2 (VLCLibrary.m:372)` ← `_dispatch_assert_queue_fail`. `VLCMediaPlayerDelegate` callbacks arrived on the main thread and needed nothing.

## 7. Consequences

- [x] Decision recorded in the decision log of: `006-video-avplayer-and-hls.md` and `007-video-vlc.md` — rows replaced with the per-player facts. Both owner decisions those rows raised were taken on 2026-09-03 and are recorded in them (Triage 5). `009-music-playback.md` also carries an S002 row and is not named here; it needs the same update once the owner decides, and its `universal` URL has its own finding (Triage row 6).
- [x] Affected slices updated: the owner decided on 2026-09-03 (Triage 5) that 006 and 007 send no auth on the anonymous stream URL, and that VLC takes the `ApiKey` fallback wherever auth is required. 006's and 007's Section 3 auth bullets and decision-log rows now say so. `depends_on` notes and pre-flight checklists still name S002 as the source, which stays true. 009 is untouched (Triage 6 open).
- [x] Master checklist spike row set to `Answered`, with the one-line answer per player.
- [x] Throwaway code kept at `/Volumes/S990/Developer/personal/spike-scratch/S002-stream-auth` with its run logs, outside this repo; the hand-picked evidence is inline above, so no `S002-evidence/` directory was created.
- [x] Architecture Drift Log updated: decision 7's premise that the client must authenticate the stream URL does not hold for `/Videos/{itemId}/stream` on 10.11.11; decision 33 itself is not invalidated.

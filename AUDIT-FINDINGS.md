# Spec audit findings — docs/ vs Jellyfin 10.11.11 OpenAPI

Read-only audit run on 2026-09-03 (runbook Phase 1). Sources: `docs/engineering-doc.md`, `docs/architecture.md`, `docs/jellyfin-api.md`, `CLAUDE.md`, `SPEC-DECISIONS.md`, `docs/jellyfin-openapi.json` (10.11.11, pulled from the running server). Nothing under `docs/`, `CLAUDE.md` or `SPEC-DECISIONS.md` was modified. Decisions are for the project owner to write into `SPEC-DECISIONS.md`.

## How this was produced

- 41 finder agents: one per endpoint the docs name (22) and one per doc section (19). Every finder read `SPEC-DECISIONS.md` first; anything it already settles was excluded.
- 105 raw findings plus 6 seeds I registered during orientation, 109 after dedup. 57 were self-rated blocking and sent to verification. 52 were self-rated low and are listed unverified in section 3.
- Each blocking finding was judged by two independent agents. Lens A re-opened the doc line and re-extracted the spec operation from the JSON and tried to refute the quotes. Lens B judged whether it truly blocks implementation or is settled by a higher-precedence doc. A finding survives only if both upheld it.
- 17 survived. The ranker merged duplicates into the 10 items in section 1. The 40 refuted items are in section 4 with each lens's reason, so a refutation can be challenged.
- I spot-checked ranks 1 to 4 by hand against the spec JSON. All four disagreements are real.

**Blocking** means: an implementer following the docs writes a call that fails against Jellyfin 10.11.11, or must guess a value, shape, status code, auth header or paging rule.

## 1. Ranked blocking ambiguities

### 1. QuickConnect/Initiate method: doc says GET, spec is POST-only

Engineering-doc.md:508 (three duplicate findings) tells the implementer to call GET /QuickConnect/Initiate; the 10.11.11 spec defines this operation (InitiateQuickConnect) only under POST, with no GET method for this path at all.

**Source A** — `docs/engineering-doc.md:508`:

> | Quick Connect start | `GET /QuickConnect/Initiate` → `{Secret, Code}` |

**Source B** — `paths['/QuickConnect/Initiate'] (methods: post only; operationId InitiateQuickConnect)`:

> paths['/QuickConnect/Initiate'] keys: ['post']
> post: {"tags": ["QuickConnect"], "summary": "Initiate a new quick connect request.", "operationId": "InitiateQuickConnect"}

There is no `get` key on this path.

**What an implementer would get wrong:** They would issue GET against /QuickConnect/Initiate and get a 405/routing failure instead of the QuickConnectResult, breaking Quick Connect sign-in — tvOS's primary auth path per the doc.

**Decision needed:** Should engineering-doc.md:508 be corrected to POST to match the spec, or is GET intentional for a reason not documented elsewhere?

### 2. Continue Watching path: doc says /Items/Resume, spec has /UserItems/Resume

Engineering-doc.md:526 (three duplicate findings) targets GET /Items/Resume for Continue Watching; the 10.11.11 spec has no such path — the resume-items operation lives at GET /UserItems/Resume.

**Source A** — `docs/engineering-doc.md:526`:

> | Continue watching | `GET /Items/Resume?userId={uid}&limit=12&mediaTypes=Video&fields=Overview` |

**Source B** — `paths — no '/Items/Resume' key; only '/UserItems/Resume' (operationId GetResumeItems) exists`:

> '/Items/Resume' in paths → False
> paths['/UserItems/Resume'].get: {"tags": ["Items"], "summary": "Gets items based on a query.", "operationId": "GetResumeItems"}

**What an implementer would get wrong:** They would call the non-existent /Items/Resume (which the templated /Items/{itemId} path could swallow with itemId='Resume') and get a 404 or the wrong response, never a resume list, breaking the Home screen's Continue Watching row.

**Decision needed:** Should engineering-doc.md:526 be corrected to GET /UserItems/Resume to match the spec, or is /Items/Resume intentional (e.g. a proxy route outside the spec)?

### 3. 403 responses have no defined MixtapeError mapping

The status-code mapping table (line 470) covers only 401, 404, 5xx and specific URLErrors; it never mentions 403, yet the spec declares a 403 Forbidden response on ordinary authenticated calls the client makes constantly — GET /UserViews, GET /Shows/{seriesId}/Episodes, and GET /Items all document it, and 403 appears on 329 of the spec's paths overall (three duplicate findings, one per endpoint).

**Source A** — `docs/engineering-doc.md:470`:

> Status code mapping: `401` → `.invalidCredentials` on the auth endpoints, `.sessionExpired` elsewhere. `404`/`5xx` → `.transport`. `URLError.cannotFindHost`/`.cannotConnectToHost`/`.timedOut` → `.serverUnreachable`.

**Source B** — `paths['/UserViews'].get.responses.403; paths['/Shows/{seriesId}/Episodes'].get.responses.403; paths['/Items'].get.responses.403`:

> "403": { "description": "Forbidden" }

**What an implementer would get wrong:** Writing the status-to-error switch, they have no MixtapeError case or fallback for 403 (it is neither 401, 404, nor 5xx) and must invent whether it becomes a new case, .sessionExpired, or a silent fold into .transport.

**Decision needed:** Should a 403 response map to a new MixtapeError case (e.g. .forbidden), reuse .sessionExpired, or fold into .transport?

### 4. Audio universal stream: doc uses api_key query param the spec doesn't define

The doc builds the music streaming URL with the token in an `api_key` query parameter, but GetUniversalAudioStream declares no such parameter in the spec and its only security scheme is an `Authorization` header — contradicting the doc's own HTTP client contract (lines 460-463) and the `headers` parameter already on VideoPlayerControlling.load (line 482).

**Source A** — `docs/engineering-doc.md:592`:

> {base}/Audio/{itemId}/universal?userId={uid}&deviceId={did}&api_key={token}

**Source B** — `paths['/Audio/{itemId}/universal'].get.parameters + components.securitySchemes.CustomAuthentication`:

> parameters: itemId, container, mediaSourceId, deviceId, userId, audioCodec, maxAudioChannels, transcodingAudioChannels, maxStreamingBitrate, audioBitRate, startTimeTicks, transcodingContainer, transcodingProtocol, maxAudioSampleRate, maxAudioBitDepth, enableRemoteMedia, enableAudioVbrEncoding, breakOnNonKeyFrames, enableRedirection (no api_key) — securitySchemes.CustomAuthentication: {type: apiKey, name: Authorization, in: header}

**What an implementer would get wrong:** They would append an undocumented, unrecognised query parameter for auth on every music stream request instead of using the header scheme the spec defines, risking audio playback being unauthenticated or rejected by the real server.

**Decision needed:** Should the audio universal stream request carry the token via the Authorization header (matching the spec's security scheme) instead of the api_key query parameter, or does Jellyfin 10.11.11 actually honour api_key here despite its absence from the spec?

### 5. VideoPlayerControlling.load's headers parameter is never explained

`VideoPlayerControlling.load` takes a `headers` dictionary — the natural place to carry an Authorization header into the player — but `headers` is never populated, referenced, or explained anywhere else in the doc, while the stream-URL construction at line 570 embeds the token as an undeclared `api_key` query parameter instead.

**Source A** — `docs/engineering-doc.md:482`:

> func load(url: URL, startAt: Duration, headers: [String: String])

**Source B** — `docs/engineering-doc.md:570 (stream URL construction) and :460-463 (HTTP client auth-header contract)`:

> line 460: **Authorization header** — one format, on every request including unauthenticated ones:
> line 463: Authorization: MediaBrowser Client="mixtape", Device="<device name>", DeviceId="<stable UUID>", Version="<CFBundleShortVersionString>", Token="<access token, omitted when signing in>"
> line 570: &mediaSourceId={id}&playSessionId={psid}&api_key={token}

Verifier note: line 460 sits under the "HTTP client contract" heading at line 449 and describes `JellyfinHTTPClient` only. Line 539 shows the doc's practice of restating auth per URL consumer ("Image URLs need no auth header... but send it anyway for consistency"). `VideoPlayerControlling.load` at line 482 gets no such statement.

**What an implementer would get wrong:** They must guess whether `headers` should carry `Authorization: MediaBrowser ...Token=...` for the stream request or be left empty because auth rides in the query string — the doc gives two auth-delivery mechanisms for the same request and resolves neither.

**Decision needed:** Should VideoPlayerControlling.load's headers parameter carry the Authorization header for the video stream request, or is it unused because auth goes through the api_key query parameter instead?

### 6. QuickConnect/Initiate 401: invalidCredentials or quickConnectUnavailable?

The doc wires /QuickConnect/Enabled's 401 to `.quickConnectUnavailable` (line 507, 'A 401 also means unavailable'), but gives /QuickConnect/Initiate's 401 — which the spec documents with the identical 'not active' meaning — no such carve-out, leaving it to fall under the blanket 'auth endpoints → .invalidCredentials' rule at line 470.

**Source A** — `docs/engineering-doc.md:470 (rule) and :508 (endpoint with no carve-out)`:

> Status code mapping: `401` → `.invalidCredentials` on the auth endpoints, `.sessionExpired` elsewhere. `404`/`5xx` → `.transport`. `URLError.cannotFindHost`/`.cannotConnectToHost`/`.timedOut` → `.serverUnreachable`.

**Source B** — `paths['/QuickConnect/Initiate'].post.responses.401`:

> "401": {"description": "Quick connect is not active on this server."}

**What an implementer would get wrong:** On a 401 from Initiate they must guess between `.invalidCredentials` (blanket rule) and `.quickConnectUnavailable` (matching spec semantics and the parallel case already made for Enabled) — the two drive different UI states (retry sign-in vs. hide Quick Connect).

**Decision needed:** Should a 401 from /QuickConnect/Initiate map to .quickConnectUnavailable (like /QuickConnect/Enabled) or to .invalidCredentials (the blanket auth-endpoint rule)?

### 7. PlaybackMethod can't express DirectPlay vs DirectStream for progress reports

The domain's PlaybackMethod enum (directAVPlayer/directVLC/transcodeHLS, line 185) encodes only which local player is used, and the resolution logic (line 568) collapses `source.supportsDirectPlay`/`supportsDirectStream` into the same branch without recording which was true — but the wire PlaybackStartInfo.PlayMethod Jellyfin expects for /Sessions/Playing requires reporting DirectPlay and DirectStream as distinct values, and no mapping or carried signal exists anywhere in the doc to produce that distinction.

**Source A** — `docs/engineering-doc.md:568-571 and :185`:

> if source.supportsDirectPlay || source.supportsDirectStream {     url = {base}/Videos/{itemId}/stream?static=true           &mediaSourceId={id}&playSessionId={psid}&api_key={token}     method = isAVPlayerNative(source) ? .directAVPlayer : .directVLC

**Source B** — `components.schemas.PlayMethod.enum` (referenced by `PlaybackStartInfo.PlayMethod`, `PlaybackProgressInfo.PlayMethod`, `PlaybackStopInfo.PlayMethod`):

> ["Transcode", "DirectStream", "DirectPlay"]

The domain enum the doc defines at `docs/engineering-doc.md:185` is `directAVPlayer`, `directVLC`, `transcodeHLS`. It names the local player, not the server-side method. The doc body at lines 609 to 613 requires `"PlayMethod": "DirectPlay" | "DirectStream" | "Transcode"`, but nothing carries the DirectPlay-vs-DirectStream distinction from the resolve step to the report step.

**What an implementer would get wrong:** Sending reportStart/reportProgress/reportStopped, they have no documented data or mapping to decide whether a direct (non-transcode) playback should report as DirectPlay or DirectStream to the server.

**Decision needed:** Should PlaybackMethod (or PlaybackReport) be extended to carry which of DirectPlay/DirectStream was actually used, and if so what determines it?

### 8. resolveVideo: repository or use case owns method selection?

§5's PlaybackRepositoryProtocol.resolveVideo returns PlaybackPlan directly (a struct embedding the already-resolved method/streamURL), but §8 explicitly assigns that same method-choosing logic to ResolveVideoPlaybackUseCase, not the repository — the two sections disagree on which layer produces the resolved plan, and §5's closed-vocabulary rule leaves no alternative intermediate DTO the repository could return instead.

**Source A** — `docs/engineering-doc.md:294`:

> func resolveVideo(itemID: String, startAt: Duration, session: UserSession) async throws -> PlaybackPlan

**Source B** — `docs/engineering-doc.md:563`:

> **Choosing the method** — this logic lives in `ResolveVideoPlaybackUseCase`, not in the repository:

**What an implementer would get wrong:** Coding to §5's signature, the repository itself would need to run the direct-play/VLC/transcode selection logic §8 assigns to the use case — they must guess the real return shape of resolveVideo and which layer owns method selection.

**Decision needed:** Does PlaybackRepositoryProtocol.resolveVideo return the fully-resolved PlaybackPlan (repository owns method selection), or should it return a different, currently-undefined shape so ResolveVideoPlaybackUseCase can own that logic as §8 states?

### 9. HomeScreen's 'Recently Added' has no service, method, or endpoint

§9 requires HomeScreen to show 'Recently Added per library', but LibraryService (§6) exposes no property or method for recently-added items — no use case, repository method, or service state anywhere in the doc covers it, even though the Jellyfin spec exposes a matching /Items/Latest endpoint.

**Source A** — `docs/engineering-doc.md:366`:

> Holds `libraries`, `continueWatching`, and a `[String: LoadState<Page<MediaItem>>]` keyed by library ID so tab switches don't refetch. Methods: `loadHome()`, `loadLibrary(id:)`, `loadMore(libraryID:)`, `refresh()`.

**Source B** — `docs/engineering-doc.md:631`:

> | `HomeScreen` | Continue Watching row, Recently Added per library |

**What an implementer would get wrong:** loadHome() is the only candidate method to populate HomeScreen, but its own service has no field to hold recently-added results and no stated call to fetch them, so they must invent the data source, method name, and cache shape from nothing.

**Decision needed:** Should LibraryService gain a recently-added data source (e.g. backed by /Items/Latest) and, if so, what method name, per-library cache shape, and refresh trigger should it use?

### 10. isWatched: computed ratio or server Played pass-through?

The doc gives two different, unreconciled sources for PlaybackState.isWatched on every BaseItemDto returned by Seasons: a computed ratio rule (position/duration >= 0.9) versus a direct pass-through of the server's own Played boolean from UserData — these can disagree (e.g. server Played=true with ratio 0.85), and PlaybackState has only one isWatched field to hold the result.

**Source A** — `docs/engineering-doc.md:261`:

> `PlaybackState.isWatched` is set when `position / duration >= 0.9`.

**Source B** — `docs/engineering-doc.md:530`:

> `UserData` on each item gives `PlaybackPositionTicks`, `Played`, `PlayedPercentage` → `PlaybackState`. during active local playback (capability #11); it never recomputes isWatched for items mapped from a list/detail response."

**What an implementer would get wrong:** The mapper implementer must guess which source wins when they disagree, and the ratio rule additionally needs a duration value PlaybackState doesn't carry (only the containing MediaItem has an optional runtime), leaving the nil-duration case undefined too.

**Decision needed:** Should PlaybackState.isWatched be a direct pass-through of the server's UserData.Played, or computed from position/duration >= 0.9 — and if computed, what duration source and nil-runtime fallback apply?

## 2. Verifier disagreement worth knowing about

Rank 4 (audio `api_key`) survived, but three sibling findings on the same mechanism for the video stream URL (`docs/engineering-doc.md:570`, `:460`, `:592`) were refuted by the blocking-lens judge as "Jellyfin's standard mechanism for URLs handed to native players", while the spec-lens judge upheld all of them. The facts are not in dispute: `api_key` appears nowhere in the 2.1MB spec, and `/Videos/{itemId}/stream` declares no security at all. The disagreement is only whether relying on undocumented server behaviour is blocking. Rank 4 stands because the same question applies to both stream URLs, and a wrong answer cannot be caught by any test that avoids the live server. Confirm once against the local server and record the answer.

## 3. Low severity, unverified

Self-rated low by the finder. Not adversarially verified. Listed so nothing found is silently dropped.

- `docs/engineering-doc.md:470` vs `paths['/System/Info/Public'].get.responses.503` — The spec documents a distinct 503 response for this endpoint, with Retry-After and Message headers and text/html body, specifically meaning 'server starting up' — but the doc's generic 404/5xx→.transport rule discards that distinction and never mentions Retry-After or the text/html content type.
- `docs/engineering-doc.md:512` vs `paths['/QuickConnect/Enabled'].get` — The doc's blanket rule says the Authorization/DeviceId header is required on 'every call in the flow', naming Initiate as the example that might be mistaken as exempt, but never says explicitly whether the availability check (Enabled) — which precedes the flow — is included. The spec's GetQuickConnectEnabled operation carries no security requirement at all (and there is no global default to fall back to), i.e. the spec models this call as unauthenticated.
- `docs/engineering-doc.md:510` vs `paths['/Users/AuthenticateWithQuickConnect'].post.responses.400` — The spec documents a 400 ('Missing token') response for this operation that neither line 510 nor the general status-code mapping table at line 470 (which only covers 401/404/5xx and specific URLErrors) accounts for.
- `docs/engineering-doc.md:319` vs `schemas.QuickConnectResult (via paths['/QuickConnect/Connect'].get.responses['200'])` — The use-case table states `PollQuickConnectUseCase` returns `UserSession?` directly from a poll of the secret, but GET /QuickConnect/Connect (the endpoint this row cites, engineering-doc.md:509) never returns a `UserSession`-shaped payload — no AccessToken, no User object, `additionalProperties: false`. Producing a `UserSession` requires a second, separate call to POST /Users/AuthenticateWithQuickConnect (line 510), which the table row for the poll use case does not mention.
- `docs/engineering-doc.md:169` vs `schemas.BaseItemDto.properties (no 'PrimaryImageTag' key; image tag lives in 'ImageTags')` — BaseItemDto has no 'PrimaryImageTag' field. The primary image tag is one entry of the 'ImageTags' dictionary, keyed by ImageType ('Primary'), not a top-level scalar property the way ParentPrimaryImageTag (line 171) is.
- `docs/engineering-doc.md:170` vs `schemas.BaseItemDto.properties.BackdropImageTags` — Domain's backdropImageTag is a single optional String, but the corresponding spec field 'BackdropImageTags' is a nullable array of strings, not a scalar.
- `docs/engineering-doc.md:522` vs `paths['/Items/{itemId}'].get.parameters` — The doc's Item-detail call appends `fields=Overview,MediaSources`, but the spec's GetItem operation (`GET /Items/{itemId}`) declares only `userId` and `itemId` as parameters — no `fields` parameter exists on this operation at all. The `fields` parameter (with `Overview`, `MediaSources` etc. as valid enum values) is declared only on the plural `GET /Items` (GetItems) operation. The doc has conflated the two operations.
- `docs/engineering-doc.md:524` vs `paths['/Shows/{seriesId}/Episodes'].get.parameters[9]` — The spec exposes startIndex and limit on this operation with no documented server-side default when both are omitted, but the doc's Episodes call never sets either, and LibraryRepositoryProtocol.episodes(...) returns a bare [MediaItem] (engineering-doc.md:288), discarding the response envelope's TotalRecordCount entirely.
- `docs/engineering-doc.md:526` vs `paths['/UserItems/Resume'].get.parameters (userId)` — The doc's call shape presents userId as a normal part of the query (as it does for every other user-scoped endpoint in §8), but on GetResumeItems the spec's parameter object carries no `required: true` — it is optional, unlike, e.g., the Library items call's userId in the same table.
- `docs/engineering-doc.md:539` vs `docs/engineering-doc.md:116` — Doc says to send the Authorization header on Primary/Backdrop image requests anyway. `ImageService` (which builds and issues these requests, §6 line 431: `func image(for: MediaItem, kind: ImageKind, maxHeight: Int) async -> UIImage?`) lives in `MixtapeServices`, whose only declared dependencies are `MixtapeUseCase` and `MixtapeDomain`. `AuthContext` and `JellyfinHTTPClient` live in `MixtapeInfrastructure` (line 241), which `MixtapeServices` is not permitted to import — and `check-layer-imports.sh` gates on exactly this edge. `ImageService`'s own signature also takes no auth/header parameter. There is no channel by which "send it anyway" can reach the request without a layer violation or an undocumented signature change.
- `docs/engineering-doc.md:169` vs `schemas.BaseItemDto.ImageTags / schemas.BaseItemDto.BackdropImageTags` — `MediaItem.primaryImageTag`/`backdropImageTag` — the exact values plugged into `tag=` on this endpoint's URL — have no like-named source field in `BaseItemDto`. `PrimaryImageTag` doesn't exist as a scalar; it comes from the `ImageTags` dict keyed by image-type string (`ImageTags["Primary"]`). `BackdropImageTags` is an array, not a scalar, so `backdropImageTag` requires picking an index (doc hardcodes URL index 0, but never states the mapper takes `.first`).
- `docs/engineering-doc.md:539` vs `paths['/Items/{itemId}/Images/{imageType}/{imageIndex}'].get (no security key) vs .post.security` — The doc frames 'no auth needed' as conditional on the tag query param being present, implying auth would otherwise be required. The spec's GET/HEAD operations for this path carry no `security` block at all — auth is unconditionally unrequired, not gated on `tag` — while the sibling POST/DELETE on the same path do declare CustomAuthentication. The doc's own instruction ('send it anyway') makes this harmless in practice, and the spec's tolerance of an extra header means no call actually fails, so this is low, not blocking.
- `docs/engineering-doc.md:308` vs `paths['/Items/{itemId}/Images/{imageType}/{imageIndex}'].get.responses['404']` — The spec documents 404 for this GET only as 'Item not found', with no distinct status or shape for the case where the item exists but has no image at that type/index (e.g. a movie with no Backdrop at index 0). The doc's `ImageURLBuilderProtocol.url(...)` returns `URL?` but never states the rule for when it returns nil — whether it inspects `backdropImageTag == nil` before building the URL at all, or builds `Backdrop/0` unconditionally and relies on a runtime 404.
- `docs/engineering-doc.md:536` vs `paths['/Items/{itemId}/Images/{imageType}/{imageIndex}'].get.parameters (fillHeight vs maxHeight)` — The spec exposes `maxHeight` and `fillHeight` as two distinct, separately-documented query parameters with different resize semantics (max-bound vs fill-box). The doc's URL template feeds its `maxHeight` value into the `fillHeight` query key, and the Domain/builder-facing parameter is itself named `maxHeight` (engineering-doc.md:308, 431) — the same name as a real, different spec parameter the doc never uses.
- `docs/engineering-doc.md:570` vs `paths['/Videos/{itemId}/stream'].get.parameters[11]` — The spec exposes `deviceId` on this endpoint specifically so the server can stop encoding processes tied to that device. The doc's video-stream URL (line 570) never includes it, while the doc's own Audio streaming URL two paragraphs later (line 592) does include `deviceId={did}` on the analogous call.
- `docs/engineering-doc.md:470` vs `paths['/Sessions/Playing/Progress'].post.responses['403']` — The engineering doc's exhaustive status-code-to-MixtapeError table (used by the single generic JellyfinHTTPClient.post that this endpoint calls) has no bucket for 403, only 401/404/5xx and specific URLErrors.
- `docs/engineering-doc.md:470` vs `paths['/Sessions/Playing/Progress'].post.responses['503']` — The spec declares a 503 response for this operation carrying Retry-After and Message headers; the doc's status-code table only generically buckets 5xx into `.transport` and never mentions Retry-After anywhere in the document.
- `docs/engineering-doc.md:470` vs `paths['/Sessions/Playing/Stopped'].post.responses` — The spec explicitly documents a 403 Forbidden response for ReportPlaybackStopped, but the doc's global status-code mapping table only handles 401 and 404/5xx — 403 is never assigned a MixtapeError case anywhere in the doc, and MixtapeError's case list (§4 Errors, lines 246-256) has no case that obviously maps to 403.
- `docs/engineering-doc.md:59` vs `docs/jellyfin-api.md:15` — §1's definition of done claims a version range ("10.10+") for acceptance testing, but the project's own API-contract methodology (jellyfin-api.md) explicitly rejects version-range compatibility claims — it shows two Jellyfin versions differing by 22 paths, two of them on the critical path (HLS master.m3u8 URLs), and pins the contract to the exact running server version for exactly that reason. Nothing in the docs establishes that 10.10 (older than the pinned 10.11.11) has the same paths/schemas the client is built against.
- `docs/engineering-doc.md:26` vs `docs/jellyfin-api.md` — §1's capability 12 (the only line defining what music playback covers) lists no transcode/fallback path, and §1 line 5 says anything not listed in In scope is out of scope. But engineering-doc.md:427 ("The HLS fallback stays in place for anything genuinely exotic") and jellyfin-api.md both treat music HLS transcode (`/Audio/{itemId}/master.m3u8`) as V1's critical path. §1 never states music transcode is in scope.
- `docs/engineering-doc.md:53` vs `docs/engineering-doc.md:423` — §1.1 lists three consequences (queue-is-one-album, no shuffle/repeat, end-of-album is a navigational event) then says "This applies to iOS only." Read plainly, "this" scopes all three to iOS, implying tvOS could have a cross-album queue, shuffle, or repeat. But `MusicPlayerService` (line 423, and again at line 769's platform-unqualified acceptance criterion) is shared and forbids shuffle/append/repeat with no iOS-only qualifier — only consequence 3 (the wallet-return navigation) is actually iOS-specific, since tvOS has no wallet to return to.
- `docs/engineering-doc.md:67` vs `docs/engineering-doc.md:806` — Section 2 explicitly inherits from Appendix A ('Per Appendix A "Platform baseline", plus:', engineering-doc.md:65) but Appendix A's platform baseline includes MacOS 26+ as a target, while §2 says no macOS target in V1. The same contradiction is duplicated verbatim in docs/architecture.md:35, and SPEC-DECISIONS.md does not mention macOS anywhere, so it is not settled there.
- `docs/engineering-doc.md:69` vs `docs/engineering-doc.md:83` — §2 says these two settings are set 'at project level' (i.e. in the .xcodeproj build settings), but §3 puts all six layer targets inside a local SPM package (MixtapeKit) rather than as app-target folders. Xcodeproj build settings do not propagate into SPM package targets — reaching them requires swiftSettings (e.g. .defaultIsolation(MainActor.self)) in Package.swift. No doc (engineering-doc.md, architecture.md, CLAUDE.md) mentions swiftSettings, defaultIsolation, or any other mechanism for the six package targets to pick up MainActor-by-default isolation or disabled approachable concurrency.
- `docs/engineering-doc.md:83` vs `docs/engineering-doc.md:89-90,697` — The same section's prose says the app-target entry file is `App.swift`, but the tree diagram three lines later and the §10 composition-root code sample both name it `MixtapeApp.swift` (matching the `struct MixtapeApp: App` type). docs/architecture.md:11-12 repeats the `App.swift` naming, so it isn't a stray typo isolated to one line.
- `docs/engineering-doc.md:123` vs `docs/engineering-doc.md:671-676` — §3 names a concrete tvOS type/file, `MovieLibraryShelf`, as the paired counterpart to iOS's `MovieLibraryGrid`. §9's tvOS screen catalog — the section that actually enumerates Presentation types — never names a `MovieLibraryShelf` type; it only describes the grid becoming 'LazyVGrid shelves' generically, while `MovieLibraryGrid` itself is listed only under the iOS screen table.
- `docs/engineering-doc.md:235` vs `docs/engineering-doc.md:356` — §9 comments the quickConnect property with three states including `.idle`, but the §4 enum it is typed as defines only `.waiting(code:)` and `.failed` — there is no `.idle` case.
- `docs/engineering-doc.md:329` vs `docs/engineering-doc.md:269` — The section's own stated rule requires one type per file with a single `callAsFunction`/`execute` entry point, but the use-case table lists a single type `ReportPlaybackUseCase` covering three distinct actions (start/progress/stopped) 'one method each' — implying three methods on one type, which violates the single-entry-point rule stated two paragraphs earlier in the same section.
- `docs/engineering-doc.md:443` vs `docs/engineering-doc.md:491` — Line 443 says AVPlayerController owns an AVPlayerLayer-backed view. Line 491 says its makeView() returns a VideoPlayer-backed representable. VideoPlayer (AVKit's SwiftUI view) and a raw AVPlayerLayer are two different, non-interchangeable ways of presenting an AVPlayer — the doc names both as if the same view.
- `docs/engineering-doc.md:539` vs `schemas.BaseItemDto (properties: AlbumId, ParentId, ParentPrimaryImageItemId, ParentPrimaryImageTag)` — The doc says to build the fallback image URL against 'the album's ID' without naming which of the three id fields on the track's BaseItemDto that is.
- `docs/engineering-doc.md:673` vs `docs/engineering-doc.md:675` — §9 asserts tvOS has the 'same information architecture' as iOS with only chrome differing, but the tab structures actually differ: iOS RootTabScreen (line 630) has 4 tabs with a unified 'Libraries' list screen (Home, Libraries, Music, Settings), while tvOS RootTabScreen has 5 tabs that split movies and shows apart (Home, Movies, Shows, Music, Settings) with no LibraryListScreen equivalent named anywhere for tvOS.
- `docs/engineering-doc.md:687` vs `CLAUDE.md:79` — §9 mandates a single file `Identifiers.swift` containing 'one enum per screen' (i.e. many enum types in one file), which directly contradicts the project-wide Swift rule in CLAUDE.md that every file holds exactly one type and the filename matches that type.
- `docs/engineering-doc.md:654` vs `docs/engineering-doc.md:447` — §9.1 describes the sleeve's tilt highlight as following 'CMMotionManager device attitude' directly, while the Infrastructure section (§7, line 447) built `DeviceAttitudeReader`/`DeviceAttitudeReading` specifically 'so the sleeve view never sees CoreMotion'. §9's own wording of the feature it defines never mentions the mandated abstraction.
- `docs/engineering-doc.md:633` vs `docs/engineering-doc.md:634` — The screens table gives `MovieLibraryGrid` an explicit column layout (2-up/4-up) and states it is paged, but the very next row for `SeriesLibraryGrid` — which the data layer serves through the same generic 'Library items' `/Items` call (line 521, `includeItemTypes={Movie|Series|MusicAlbum}`) — gives none of that detail.
- `docs/engineering-doc.md:726` vs `docs/engineering-doc.md:619-636 (Screens — iOS table) and :674-680 (Screens — tvOS)` — §10 names a top-level view `RootScreen()` and describes it routing to a `.loading` → "splash" state and a `.signedOut` → "the server/sign-in flow" state, but neither `RootScreen` nor any "splash" screen appears anywhere else in the docs (§9's Presentation screen tables for iOS and tvOS list every other screen — ServerEntryScreen, SignInScreen, QuickConnectScreen, RootTabScreen, etc. — but never RootScreen or a splash screen), and "the server/sign-in flow" doesn't name which of ServerEntryScreen/SignInScreen/QuickConnectScreen it resolves to or in what order.
- `docs/engineering-doc.md:739` vs `docs/engineering-doc.md:897` — Section 11 tells the implementer to write unit-test repository doubles named `Mock*`, but the same document's own naming-convention rule (and CLAUDE.md's identical rule) reserves `Mock*` for main-target preview doubles and requires test-target doubles to be named `Stub*`.
- `docs/engineering-doc.md:744` vs `docs/engineering-doc.md:905` — Section 11 scopes the deferred XCUITest work as one happy-path test per platform (two tests total, both walking the same Movies→Play flow), while the doc's own 'Commands to verify a new project' checklist scopes it as one happy-path test per screen (many tests, one per screen).
- `docs/engineering-doc.md:731` vs `CLAUDE.md:96` — Engineering doc §11 carves out an explicit exception permitting XCTest for XCUITest; CLAUDE.md's Testing section states 'never XCTest' with no such exception.
- `docs/engineering-doc.md:765` vs `docs/engineering-doc.md:650` — AC13a asserts that rotating an iPhone to landscape yields the 3×3 grid, but the layout rule it must be built from (line 650) keys the grid to SwiftUI horizontal size class (compact/regular), and only iPhone Plus/Max-class devices reach 'regular' width in landscape — a standard iPhone stays 'compact' width in landscape and would still show 2×2. The AC and the implementation rule disagree on which iPhones get 3×3 on rotation.
- `docs/engineering-doc.md:792` vs `docs/engineering-doc.md:791` — Build order §13 numbers two different steps '11' — the tvOS presentation layer and the XCUITests/accessibility/Reduce-Transparency work are both labelled step 11, and the list never reaches step 12. SPEC-DECISIONS.md itself cites 'build-order step 11's XCUITest work' (line 75) and 'Step 11 bundles all four together' (line 93), i.e. it uses '11' to mean the second of the two, silently resolving which one it means without flagging that the source list is mis-numbered.
- `docs/engineering-doc.md:806` vs `docs/engineering-doc.md:67` — Appendix A's platform baseline (copied verbatim from the generic trimr template, and also duplicated in docs/architecture.md:35) lists MacOS 26+ as a required, in-scope platform, directly contradicting the project's own scope statement two sections earlier in the same file, and CLAUDE.md:19 ('No macOS'), which excludes macOS entirely.
- `docs/engineering-doc.md:837` vs `docs/engineering-doc.md:33` — Appendix A (also duplicated verbatim in docs/architecture.md:65) carves out a persistence exception for SwiftData/ModelContainer/@Model living in an `AppData/Persistence/` folder, but nothing in the project's actual capability list or Data layer section (engineering-doc.md §8) describes any local persistence need — 'Downloads and offline playback' is explicitly out of scope, and the only caching described anywhere (engineering-doc.md:28, 372, 431) is in-memory (NSCache, per-series dictionary cache), never SwiftData. The folder name also uses the generic `AppData` prefix rather than the project's actual `MixtapeData` target.
- `docs/engineering-doc.md:927` vs `docs/engineering-doc.md:89` — Appendix B's iOS verification commands (927, 929) name the scheme 'Mixtape', but the doc's own §3 tree (line 89) names the iOS app target 'MixtapeiOS', architecture.md:11 agrees on 'MixtapeiOS', and CLAUDE.md:139 calls it the 'iOS' scheme — three different names for one scheme across the doc set. Checked against the actual project: MixTape.xcodeproj/xcshareddata/xcschemes/ contains iOS.xcscheme and tvOS.xcscheme, and project.pbxproj's productName values are MixTape/mixtape.tv, none matching 'Mixtape'. So Appendix B's literal `-scheme Mixtape` does not match any real scheme name.
- `docs/engineering-doc.md:929` vs `CLAUDE.md:159` — Appendix B's iOS and tvOS test commands (929-930) hardcode `OS=26.0` in the destination string, directly contradicting CLAUDE.md's explicit rule that this exact pinned value fails on this machine and that a simulator must be resolved at runtime via `xcrun simctl list devices available` instead.
- `docs/engineering-doc.md:929` vs `CLAUDE.md:140` — CLAUDE.md's slice-gate criteria mandate `-skip-testing:iOSUITests` / `-skip-testing:tvOSUITests` on every test invocation (CLAUDE.md:144-145), calling that 'the only permitted exclusion'. Appendix B's own test commands (929-930) omit both flags entirely.
- `docs/engineering-doc.md:937` vs `docs/jellyfin-api.md:5` — Appendix C states the OpenAPI spec is served at `{base}/api-docs/swagger` and instructs checking it against the running server before trusting endpoint shapes. docs/jellyfin-api.md and CLAUDE.md:116-117 both say the actual working URL this project pulled the checked-in spec from is `/api-docs/openapi.json` (confirmed by the refresh command at jellyfin-api.md:40, which curls that exact path). `/api-docs/swagger` is Jellyfin's interactive Swagger UI (HTML), not the raw JSON spec. Separately, line 937's 'any endpoint shape below is current' dangles — nothing below Appendix C is an endpoint shape, only external links.
- `docs/engineering-doc.md:944` vs `paths['/Users/{userId}'].get, paths['/Users/{userId}'].delete, paths['/Users/{userId}/Policy'].post` — Appendix C links out under the label 'Deprecated `/Users/{userId}/…` paths'. In the checked-in 10.11.11 spec, `/Users/{userId}` (GET, DELETE) and `/Users/{userId}/Policy` (POST) all exist with no `deprecated` key at all — the spec itself does not flag them as deprecated for this server version.
- `docs/architecture.md:35` vs `docs/engineering-doc.md:67` — architecture.md's Platform baseline requires a MacOS 26+ target, while the higher-precedence engineering doc (and CLAUDE.md line 19: 'iOS 26+, tvOS 26+. No macOS.') explicitly excludes macOS from V1.
- `docs/architecture.md:57` vs `docs/engineering-doc.md:114` — architecture.md's layer-dependency table gives AppInfrastructure's allowed dependency as generic 'Foundation, SDKs' with no Domain edge, while engineering-doc.md's concrete target table requires MixtapeInfrastructure to depend on MixtapeDomain plus the specifically-named VLCKit SDK.
- `docs/architecture.md:146` vs `CLAUDE.md:139` — architecture.md's 'Commands to verify a new project' shows only an iOS destination with no -skip-testing flags, while CLAUDE.md's slice gate mandates both iOS and tvOS schemes plus explicit -skip-testing flags for both UI test bundles.
- `CLAUDE.md:19` vs `docs/engineering-doc.md:806` — CLAUDE.md states no macOS target exists; engineering doc's Appendix A (the architecture template CLAUDE.md itself names as authoritative) states MacOS 26+ is a required baseline, and docs/architecture.md:35 copies that line verbatim into the project-specific platform baseline section.
- `CLAUDE.md:139` vs `docs/engineering-doc.md:927-928` — CLAUDE.md's gate criteria call the two build schemes 'iOS' and 'tvOS' (repeated at lines 144-145's inline comments), but the project's own concrete verification commands in engineering doc Appendix B name the actual schemes `Mixtape` and `MixtapeTV`.
- `CLAUDE.md:81` vs `docs/engineering-doc.md:621` — CLAUDE.md requires preview states {empty, nil, failure} (matching the generic Appendix A wording and architecture.md:126), while engineering doc's project-specific §9 requires {loaded, empty, failure} — dropping 'nil' in favour of a 'loaded' success-state preview.

## 4. Refuted after verification

Each was self-rated blocking, then at least one lens refuted it. Reasons are the verifiers' own words, trimmed. Challenge any of these if the reason looks wrong.

### `docs/engineering-doc.md:512`

Neither doc nor spec states the Authorization header value format (MediaBrowser Token=..., Client=..., Device=..., DeviceId=..., Version=...). Check eng doc §7 lines 435-494 for it before upholding.

- REFUTED: docs/engineering-doc.md:435-437 (§7, "HTTP client contract" → "Authorization header" subsection) states the header grammar verbatim: `Authorization: MediaBrowser Client="mixtape", Device="<device name>", DeviceId="<stable UUID>", Version="<CFBundleShortVersionString>", Token="<access token, omitted when signing in>"`. It also specifies field sources (Client is literal "mixtape", Device is UIDevice.current.name/"Apple TV", DeviceId is a Keychain-stored UUID, Version is CFBundleShortVersionString) and explicitly forbids X-Emby-Authorization. The finding's docQuote (line 512, Quick Conne
- REFUTED: Eng doc §7 (docs/engineering-doc.md, 'HTTP client contract' subsection, immediately above line 512) states the exact header grammar verbatim, plus notes not to use X-Emby-Authorization, DeviceId persistence/source, and Device value per platform. SPEC-DECISIONS.md is silent but doesn't need to override anything — the eng doc already answers unambiguously, so an implementer would not have to guess and would not get a 401.

### `docs/engineering-doc.md:525`

Album tracks call has no startIndex/limit yet line 528 says paged responses map to Page<MediaItem>. Unclear whether the album track list is paged, and what the server default limit is.

- REFUTED: Both quotes check out verbatim (engineering-doc.md:525 and :528), but the doc resolves the ambiguity itself just 14 lines earlier: the repository protocol at line 289 declares `func tracks(albumID: String, session: UserSession) async throws -> [MediaItem]` -- a plain unpaged array with no PageRequest parameter -- in explicit contrast to line 285's `func items(in libraryID:...page: PageRequest...) async throws -> Page<MediaItem>` for library items. The line-528 'Paged responses...-> Page<MediaItem>' note applies to the calls whose repo method actually returns Page<MediaItem> (library i
- REFUTED: Eng doc line 289 declares `func tracks(albumID: String, session: UserSession) async throws -> [MediaItem]` — plain array, not `Page<MediaItem>`. Line 521 (library items) explicitly appends `&startIndex={n}&limit=60`; line 525 (album tracks) deliberately omits both. Per the OpenAPI spec, limit/startIndex are optional with no stated default, so omitting limit returns the full result set (consistent w/ §1.1 "queue is the album" needing the complete track list, never a truncated page). Line 528's Page<MediaItem> note describes the wrapper shape `/Items` always returns, not a mandate that 

### `docs/engineering-doc.md:570`

Stream and universal-audio URLs pass the token as api_key query param. Verify the spec declares it and under what casing; if absent, it is undocumented server behaviour.

- upheld: Doc quote at engineering-doc.md:570 is verbatim and in context. Spec check confirms api_key is absent: /Videos/{itemId}/stream .get has security=None and its ~50 query parameters contain no api_key/apiKey/ApiKey; /Audio/{itemId}/universal .get declares security via CustomAuthentication (header Authorization only) and likewise has no api_key query param. A full string search of the whole 2.1MB spec for 'api_key' (case-insensitive) returns zero hits. The only declared auth mechanism in the entire spec is the header-based CustomAuthentication scheme. Finding stands as-is; no corrected quo
- REFUTED: Verified: neither /Videos/{itemId}/stream nor /Audio/{itemId}/universal declares api_key or ApiKey as a query param in docs/jellyfin-openapi.json; only a header scheme (CustomAuthentication, name=Authorization, in=header) is declared, and stream has no operation-level security at all. So the finding's factual premise (absent from spec) is correct. But that doesn't make it blocking: Jellyfin auth is enforced by middleware ahead of per-endpoint parameter binding, so OpenAPI silence on a query fallback is expected, not evidence the server rejects it. Eng doc §"Choosing the method" and mu

### `docs/engineering-doc.md:507`

401 is only defined for QuickConnect/Enabled. Behaviour on 401 for every authenticated call (expired or revoked token) is undefined unless §4 Errors covers it.

- REFUTED: Grep of docs/engineering-doc.md Section 4 Errors shows `case sessionExpired // 401 on an authenticated call` in the MixtapeError enum (~line 253). That is exactly the 401-on-authenticated-call behaviour the finding claims is undefined -- a defined, distinct domain error from quickConnectUnavailable. The specQuote placeholder was an instruction to check, and checking shows no gap.
- REFUTED: eng-doc §4 Errors already names the case: `sessionExpired // 401 on an authenticated call` in the MixtapeError enum (docs/engineering-doc.md, Errors section near line 253). SPEC-DECISIONS.md is silent on this and doesn't need to override anything since the eng doc already gives an unambiguous answer. Implementer maps any 401 from an authenticated call to .sessionExpired — no guess needed on status code, shape, or handling category.

### `docs/engineering-doc.md:134`

The doc's Domain entity for the /System/Info/Public response declares id, name, and version as non-optional String, but the spec marks all three fields nullable in the response schema.

- upheld: Doc quote at engineering-doc.md:133-137 confirmed verbatim (ServerIdentity with non-optional id/name/version String). Spec schema PublicSystemInfo confirmed: Id, ServerName, Version all carry "nullable": true. Both quotes are accurate and the disagreement is real — no null-handling/DTO shape given in doc, no elsewhere-grep escape found.
- REFUTED: Not blocking. (1) Doc gives Domain shapes, not DTO shapes, for every endpoint by design (§8: DTOs are internal, live beside the repository, mapped via *Mapper) — "no DTO shape stated" is the doc's normal pattern everywhere, not a gap unique to this struct. (2) Domain optionality elsewhere already mirrors real-world nullability where it matters (MediaItem.overview: String?, productionYear: Int?, seriesName: String?) — ServerIdentity's non-optional id/name/version reads as a deliberate assertion: a response without them isn't a valid server identity, consistent with ValidateServerUseCas

### `docs/engineering-doc.md:248`

MixtapeError.notAJellyfinServer is declared but never wired to any condition anywhere in the doc — the general status-code mapping only covers 401/404/5xx/URLError cases and routes them to .invalidCredentials/.sessionExpired/.transport/.serverUnreachable, leaving no rule for when notAJellyfinServer should fire instead of .decoding or .transport.

- upheld: Both quotes check out verbatim and in context. Line 248 `case notAJellyfinServer` sits inside the MixtapeError enum (lines 245-256). Line 470 status-code mapping (401->.invalidCredentials/.sessionExpired, 404/5xx->.transport, URLError->.serverUnreachable) and line 505's Validate-server row (GET /System/Info/Public -> {Id, ServerName, Version}. Unauthenticated.) are exact matches. Grepped the whole doc for notAJellyfinServer: it appears only once, at line 248 (plus an unrelated comment at line 134 on ServerIdentity) — no acceptance criterion, pure-rule, or test-plan section anywhere tie
- REFUTED: Not blocking. Neither the eng doc nor SPEC-DECISIONS.md states a trigger for .notAJellyfinServer, but no acceptance criterion (eng doc §12, lines 750-773) exercises this case -- AC-1 only covers a scheme-less localhost URL resolving successfully, not a non-Jellyfin URL. The wire contract for the relevant call (GET /System/Info/Public -> {Id, ServerName, Version}, unauthenticated, doc line 505) is fully specified and works against 10.11.11 regardless of how the implementer routes a bad response. An implementer can reasonably special-case a decode failure on that one validate-server cal

### `docs/engineering-doc.md:470`

The engineering doc asserts POST /Users/AuthenticateByName maps a 401 response to .invalidCredentials, but the OpenAPI contract for this exact operation documents only 200 and 503 as possible responses — no 401 is declared anywhere in the operation's response set.

- upheld: Verified both quotes exactly. docs/engineering-doc.md:470 does read "Status code mapping: `401` → `.invalidCredentials` on the auth endpoints, `.sessionExpired` elsewhere. `404`/`5xx` → `.transport`. `URLError.cannotFindHost`/`.cannotConnectToHost`/`.timedOut` → `.serverUnreachable`." Re-extracted paths['/Users/AuthenticateByName'].post.responses directly from docs/jellyfin-openapi.json: the only keys present are '200' (AuthenticationResult) and '503' (Retry-After/Message headers, text/html, no schema). No 401 (or 400/403/404) response is declared for this operation. The doc's 401->.in
- REFUTED: Not blocking. Eng doc line 470 gives an unambiguous, already-made call (401→.invalidCredentials on auth endpoints) — implementer doesn't guess, just codes it. Spec's silence on 401 for AuthenticateByName is the known Jellyfin OpenAPI gap (errors from global exception filters aren't attribute-annotated, so codegen omits them from most operations) — not evidence 401 won't occur. Real Jellyfin (all versions incl. 10.11.11) returns 401 on bad credentials at this endpoint; doc even reuses 401 as a signal at line 507 (QuickConnect/Enabled), showing deliberate use of known server behaviour, 

### `docs/engineering-doc.md:507`

The doc instructs the implementer to treat a 401 from GET /QuickConnect/Enabled as meaning Quick Connect is unavailable, but the spec's GetQuickConnectEnabled operation defines only 200 and 503 responses — there is no 401 in its responses object at all. The 401 response ('Quick connect is not active on this server') is instead defined on the *different* operation InitiateQuickConnect (POST /QuickConnect/Initiate), which the doc covers separately two rows below (line 508).

- upheld: Doc line 507 quote confirmed exact and in context. Spec's GetQuickConnectEnabled (GET /QuickConnect/Enabled) responses object contains only 200 and 503 keys — no 401 defined. specQuote matches verbatim. Finding stands: doc's 401 branch has no basis in this operation's spec.
- REFUTED: Spec confirmed: /QuickConnect/Enabled defines only 200/503; the 401 ('Quick connect is not active on this server') belongs solely to POST /QuickConnect/Initiate. SPEC-DECISIONS.md is silent on QuickConnect. But CLAUDE.md states this exact OpenAPI spec was pulled from the live 10.11.11 server ('spec and server agree'), so per the project's own stated ground truth that endpoint never actually returns 401. The doc's extra '401 also means unavailable' clause on the Enabled row is therefore dead/defensive code that never fires against the real server -- not a call that fails, and not a gen

### `docs/engineering-doc.md:470 (and :360)`

The doc's only stated rule for a 404 from GET /QuickConnect/Connect is the generic '404 → .transport'. Domain defines a dedicated `.quickConnectExpired` case (engineering-doc.md:251) but the doc (line 360) wires it ONLY to a client-side 5-minute local timer, never to the server's 404 'Unknown quick connect secret' response. Nothing says whether the 5s polling loop (line 360) should stop or keep retrying when `quickConnectState` throws mid-poll, and nothing says a 404 mid-poll should surface as `.quickConnectExpired` rather than a generic `.transport(String)`.

- upheld: Both quotes verified verbatim. docs/engineering-doc.md:470 contains the exact generic 404->.transport mapping; :360 contains the exact quote wiring .quickConnectExpired only to the 5-minute local timer. .quickConnectExpired is declared at :251 (confirmed). Spec check: paths['/QuickConnect/Connect'].get.responses['404'] has description 'Unknown quick connect secret.' with ProblemDetails schema -- exact match, endpoint is unauthenticated (security: None). Grepped entire doc for poll/retry/timeout language (lines 17,319,360,509,669,740,773) -- none resolve mid-poll 404 behaviour; line 740
- REFUTED: 404 mapping is explicit and unconditional: JellyfinHTTPClient maps status codes at the transport layer for every endpoint (doc lines 441, 470: '404/5xx -> .transport'), no per-endpoint exception carved out, so QuickConnect/Connect's 404 unambiguously yields .transport(String) -- not a guessed status code. Polling-loop behaviour on a thrown error follows the one convention used everywhere else in the doc: every stateful enum (LoadState, PlayerStatus, QuickConnectUIState) treats a thrown error as terminal -- .failed(MixtapeError) -- with no 'retry on error' pattern shown anywhere in the

### `docs/engineering-doc.md:470`

The engineering doc's HTTP-client status-code mapping (§7) has no branch for 400, but the spec documents 400 as this operation's only defined failure response (alongside 200 and 503) — a case AuthenticateByName's spec does not even declare.

- upheld: Doc quote at engineering-doc.md:470 is exact and in context — the status-code mapping table only covers 401/404/5xx/URLError cases, no 400 branch anywhere in the doc (grep for "400" in engineering-doc.md returns zero hits). Spec confirms /Users/AuthenticateWithQuickConnect.post.responses has exactly {200, 400: "Missing token.", 503} — no 401 declared for this operation. By contrast /Users/AuthenticateByName.post.responses has only {200, 503} — no 400, no 401 — so the doc's "same shape as password sign-in" note (line 510) applies only to the 200 body, and the two ops' error surfaces gen
- REFUTED: Spec's 400 is "Missing token" (client sent no/empty Secret) — a client bug, not "an unrecognised or expired Secret" as the finding claims. Per eng doc §8, Finish is only called with a Secret obtained from Initiate and after Poll confirms Authenticated:true, so a correctly-built call never sends an empty Secret: the call does not fail against 10.11.11. Of the finding's 3 "plausible landings," two are already ruled out by the docs, not taste: .quickConnectExpired is explicitly client-owned (line 360, the 5-minute poll timer sets it; expiry is never derived from a server response code), 

### `docs/engineering-doc.md:521`

The Library-items call never sets enableUserData, and the spec states an explicit default (true) for the sibling params enableTotalRecordCount and enableImages but is silent on enableUserData's default -- yet engineering-doc.md:530 requires UserData.PlaybackPositionTicks/Played/PlayedPercentage to populate the non-optional PlaybackState on every MediaItem the Library page renders.

- upheld: All primary-source claims check out. docs/engineering-doc.md:521 quote matches verbatim (grep confirms line number). Spec params confirmed: enableUserData has {"type":"boolean"} with no default; enableTotalRecordCount and enableImages both carry {"type":"boolean","default":true} — exact asymmetry claimed. Grepped engineering-doc.md for "enableUserData" — zero other hits, so the doc never resolves the omission elsewhere. Line 172 confirmed non-optional: `let playback: PlaybackState` (no `?`). BaseItemDto.UserData itself is schema-nullable, reinforcing that an implementer genuinely canno
- REFUTED: Not blocking. Two independent reasons: (1) enableUserData is a nullable bool query param with no required validation — the /Items call succeeds against 10.11.11 whether it's present or not, so no request failure risk either way. (2) Jellyfin's DtoOptions defaults EnableUserData=true server-side (the swagger omission is because the controller signature uses `bool? enableUserData = null` rather than a literal `= true`, unlike enableImages/enableTotalRecordCount which use literal defaults Swashbuckle can render) — this is why virtually every Jellyfin client (incl. jellyfin-web's library 

### `docs/engineering-doc.md:525`

The Album tracks call at line 525 carries no startIndex/limit, yet line 528 states paged /Items responses map to Page<MediaItem> -- and the spec's own limit/startIndex parameters declare no default (unlike enableTotalRecordCount/enableImages, which do declare default: true).

- upheld: Verified both quotes exactly as given, in context. docs/engineering-doc.md:525 Album tracks row has no startIndex/limit, unlike the Library items row (521, limit=60) and Continue watching row (526, limit=12) right beside it. Line 528's Page<MediaItem> sentence sits directly below. Spec check confirms: paths['/Items'].get.parameters[33] (startIndex) and [34] (limit) schemas are `{"type":"integer","format":"int32"}` with no `default` key, while [84] enableTotalRecordCount and [85] enableImages both carry `"default": true`. Grepped engineering-doc.md and SPEC-DECISIONS.md for any resolvin
- REFUTED: Eng doc §5 repository protocol (line 289) declares `func tracks(albumID:session:) async throws -> [MediaItem]` — a flat array, not `Page<MediaItem>`. Only `items(in:kind:page:session:)` (line 285, library items) takes a `PageRequest` and returns `Page<MediaItem>`. Line 528's "Paged responses are {Items,TotalRecordCount,StartIndex} -> Page<MediaItem>" is documenting the shape for calls that ARE paged (i.e. Library items, which explicitly has startIndex/limit in its endpoint row) — it does not retroactively make Album tracks paged. The Album tracks endpoint row (525) has no startIndex/l

### `docs/engineering-doc.md:470`

GET /Items declares a 403 response in the spec, but the HTTP client's status-code mapping (the only place MixtapeError cases are assigned) covers only 401 and 404/5xx -- 403 is not mentioned anywhere in the doc.

- upheld: Both quotes verified verbatim and in context: engineering-doc.md:470 has no 403 branch (401→invalidCredentials/sessionExpired, 404/5xx→transport, specific URLErrors→serverUnreachable), and grep confirms no other mention of 403 anywhere in the doc. The spec confirms /Items.get.responses includes 403:{"description":"Forbidden"} verbatim, alongside a real per-operation security requirement (CustomAuthentication/DefaultAuthorization), so 403 is a genuine reachable response, not a stray/unused declaration. The finding stands as given — no correction needed.
- REFUTED: MixtapeError (eng doc §4, lines 246-256) is a closed enum. `.sessionExpired` is annotated "401 on an authenticated call" and `.invalidCredentials` is 401-on-auth (line 470), so neither admits 403; every other case (`.serverUnreachable`, `.notAJellyfinServer`, `.quickConnect*`, `.noPlayableSource`, `.decoding`) is semantically excluded on its face. `.transport(String)` is the sole remaining slot, and it is already the documented bucket for 404 and 5xx — line 470 reads as "401 is special; everything else is transport," with 404/5xx cited as examples of that "everything else," not an exh

### `docs/engineering-doc.md:470`

The engineering doc's global status-code mapping table assumes every endpoint including GetItem can return 404 (mapped to `.transport`), but the GetItem operation's `responses` object in the spec declares only 200, 401, 403 and 503 — there is no 404 response defined for `GET /Items/{itemId}`. What Jellyfin 10.11.11 actually returns for a non-existent or inaccessible itemId on this operation (a 404, a 403, or a 200 with a default/empty DTO) is undefined by the contract.

- upheld: Both quotes verified verbatim. docs/engineering-doc.md:470 contains the exact quoted global mapping sentence with no per-endpoint exception. The GetItem (get) operation on paths['/Items/{itemId}'] in docs/jellyfin-openapi.json declares responses 200, 503, 401, 403 only — 404 is absent, confirmed by direct extraction. Sibling operations on the same path (POST UpdateItem, DELETE DeleteItem) both explicitly declare 404 with a ProblemDetails schema, sharpening the contrast: the omission on GET looks deliberate/meaningful, not a doc oversight. So the contract genuinely leaves 'missing/inacc
- REFUTED: Not blocking. The doc's status mapping (engineering-doc.md:470) is a single client-wide switch on the actual runtime HTTP status code in `JellyfinHTTPClient`, applied uniformly to every call — it is not derived from, or gated on, each operation's declared `responses` set in the OpenAPI spec. "404/5xx → .transport" already covers GetItem unambiguously; the implementer writes this once and it fires for any endpoint that happens to return 404, regardless of whether that operation's spec entry lists 404. There's also no feature or acceptance criterion anywhere in engineering-doc.md or SPE

### `docs/engineering-doc.md:470`

The doc's exhaustive status-code-to-MixtapeError mapping table covers only 401, 404, 5xx, and specific URLError cases, but the spec declares 403 as a distinct possible response for GetSeasons, separate from 401 and 404/5xx.

- upheld: Doc quote at engineering-doc.md:470 confirmed verbatim and in context — the status-code mapping only covers 401, 404/5xx, and specific URLError cases; no 403 case exists, and grep confirms 403/Forbidden appears nowhere else in the doc. Spec quote confirmed: GetSeasons (/Shows/{seriesId}/Seasons GET) responses include a distinct 403 entry alongside 200/401/404/503, with the operation requiring CustomAuthentication security. MixtapeError enum has no forbidden/permission-denied case. Finding is real and both quotes are accurate as given.
- REFUTED: 403 is generic OpenAPI boilerplate present on ~150 GET endpoints including GetSeasons, not a distinct scenario. MixtapeError already provides `.transport(String)` as the catch-all bucket for any status not in the named buckets (401/404/5xx) — the doc already uses it that way for 5xx. An implementer routes 403 through `.transport` via a default case in the switch; no new enum case is needed, no guess on request shape/auth header/paging is required, and the network call itself does not fail against 10.11.11 regardless of which bucket 403 lands in. This is a documentation-completeness ni

### `docs/engineering-doc.md:523`

The doc's literal query string for Seasons omits `enableUserData`, yet the doc elsewhere (line 530) relies on every returned item carrying UserData to populate the non-optional `playback: PlaybackState` field on MediaItem. The spec marks enableUserData optional with no stated default and separately marks UserData itself as nullable.

- upheld: Both quotes check out verbatim and in context. docs/engineering-doc.md:523 is exactly `| Seasons | \`GET /Shows/{seriesId}/Seasons?userId={uid}\` |` — no enableUserData. Line 530 generically states 'UserData on each item gives PlaybackPositionTicks, Played, PlayedPercentage -> PlaybackState', which the doc applies to all the list endpoints above it including Seasons, feeding the non-optional MediaItem.playback field. Spec confirms: paths['/Shows/{seriesId}/Seasons'].get has an enableUserData query param with description 'Optional. Include user data.' and no default key in its schema; c
- REFUTED: Not blocking. enableUserData is an optional boolean on Seasons — omitting it cannot make the call fail against 10.11.11 (no required-param error, no shape change forced). SPEC-DECISIONS.md is silent on this and the doc doesn't state it in words, but the doc's own §8 table settles the practical question structurally: the Item detail row (line 522, same table) hits `GET /Items/{itemId}`, which per the spec has NO enableUserData parameter at all — no opt-in exists there — yet the doc relies on that call returning UserData for the very same non-optional PlaybackState field. The only coher

### `docs/engineering-doc.md:470`

GetResumeItems (/UserItems/Resume) explicitly declares a 403 Forbidden response, but the doc's status-code-to-MixtapeError mapping table only covers 401, 404, and 5xx — 403 is not mentioned anywhere in §7's HTTP client contract.

- upheld: Both quotes confirmed verbatim. docs/engineering-doc.md:470 status-code mapping table only covers 401, 404/5xx, and specific URLError cases — no 403 case. Spec confirms: paths['/UserItems/Resume'].get.responses has keys ['200','503','401','403'], security=[{'CustomAuthentication':['DefaultAuthorization']}], and responses['403'] == {'description': 'Forbidden'} exactly matching specQuote. grep -n "403" docs/engineering-doc.md returns zero hits anywhere in the doc, confirming 403 is genuinely unmapped, not addressed elsewhere. Finding stands as given; no quote correction needed.
- REFUTED: 403 is not a Resume-specific gap: grep shows `"403": {` appears 329 times across docs/jellyfin-openapi.json, on essentially every authenticated endpoint (330 have 401 too) — it's boilerplate the Jellyfin OpenAPI generator stamps on every secured route, not a deliberate per-call behaviour worth its own line in §7's mapping table. The doc's table already establishes the pattern for unenumerated codes: 404 and 5xx are grouped together into `.transport(String)`, a generic case that carries a human-readable message. Because JellyfinHTTPClient switches on a plain Int status code (not a clos

### `docs/engineering-doc.md:530`

The whole 'Continue watching' feature depends on UserData.PlaybackPositionTicks being present on every item returned by GET /UserItems/Resume (doc line 526's query string), but that call never passes enableUserData, and unlike enableImages/enableTotalRecordCount on the same operation (which declare default: true / default: false), enableUserData's schema states no default at all.

- upheld: Confirmed, not refuted. Doc line 526: `GET /Items/Resume?userId={uid}&limit=12&mediaTypes=Video&fields=Overview` — no enableUserData in query. Line 530 quote verbatim matches. Spec has only `/UserItems/Resume` (doc's `/Items/Resume` doesn't even exist in spec — separate wrinkle, but implementer must use the spec path anyway). That op's enableUserData param: `{"type": "boolean"}`, no default — verbatim match to specQuote. enableImages does declare `"default": true` (matches); enableTotalRecordCount actually also defaults `true`, not `false` as the finding's whyBlocks text claims — minor
- REFUTED: Not unique to Resume: checked whole spec — enableUserData has 0/27 declared defaults, incl. /Items and /Shows/.../Episodes, which eng doc also uses for UserData-derived fields (Played/PlaybackState) without ever passing enableUserData. Eng doc never passes enableUserData/enableImages/enableTotalRecordCount on ANY call — deliberate doc-wide convention, not a Resume-specific gap. This is a known Jellyfin OpenAPI-gen quirk: server includes UserData by default whenever userId is supplied, regardless of missing schema default. SPEC-DECISIONS.md silent (grepped, empty), but no higher-preced

### `docs/engineering-doc.md:470`

The spec declares a 403 response for POST /Items/{itemId}/PlaybackInfo, but the doc's global status-code-to-MixtapeError mapping only covers 401, 404, and 5xx. 403 is not a 404 and not a 5xx, so it falls outside every bucket in the table.

- upheld: Both quotes verified verbatim. docs/engineering-doc.md:470 contains exactly the quoted mapping sentence (401->.invalidCredentials/.sessionExpired, 404/5xx->.transport, specific URLErrors->.serverUnreachable) with no 403 case anywhere in it. The spec's POST /Items/{itemId}/PlaybackInfo operation responses object genuinely includes a top-level "403": {"description": "Forbidden"} entry (alongside 200, 401, 404, 503), confirmed by direct extraction from docs/jellyfin-openapi.json (not nested under a $ref). 403 is not 404 and not 5xx (503 is the only 5xx present), so it falls outside every 
- REFUTED: Not blocking. `MixtapeError` (eng doc line 246-256) has exactly one String-carrying case: `.transport(String)`, documented as "human-readable, already localised" — a generic display bucket for any HTTP failure not otherwise special-cased, not an exhaustive whitelist. The status-mapping line (470) names 401 (split by context) and 404/5xx as the cases needing distinct semantic treatment; any Swift switch on status code compiles only with a `default:`, and `.transport` is the only enum case shaped to receive it (invent-a-case contradicts the documented enum; leave-unhandled isn't exhaust

### `docs/engineering-doc.md:559`

PlaybackInfoResponse has a third top-level field, ErrorCode (NotAllowed/NoCompatibleStream/RateLimitExceeded), that the doc's description of the response never mentions. Neither the response-shape description at line 559 nor the ResolveVideoPlaybackUseCase pseudocode at lines 565-577 reads or branches on it, and MixtapeError (lines 246-256) has no case for any of the three values.

- upheld: Both quotes verified verbatim and in context. docs/engineering-doc.md:559 reads exactly as quoted, and the pseudocode at 565-577 only branches on supportsDirectPlay/supportsDirectStream/transcodingUrl, falling to .noPlayableSource — no read of ErrorCode. MixtapeError (lines 246-256) has no case matching NotAllowed/NoCompatibleStream/RateLimitExceeded. The spec's PlaybackInfoResponse schema quote matches exactly, confirming ErrorCode is a real nullable top-level field. grep across the whole doc for "errorcode"/"NotAllowed"/"NoCompatibleStream"/"RateLimitExceeded" returns zero hits, so t
- REFUTED: Not blocking. Pseudocode (eng doc :566-577) already gives the exact, unambiguous fallback: pick first MediaSource, else throw .noPlayableSource - covers empty/unusable MediaSources regardless of cause (rate-limited, not-allowed, no-compatible-stream all collapse there by the doc's own algorithm, no guessing required). Swift Decodable ignores an undecoded ErrorCode field - no decode failure, call won't fail against 10.11.11. No AC in §12 or scope item in §1 asks for per-ErrorCode messaging. SPEC-DECISIONS.md (98 lines, decisions 1-4) is silent on this and doesn't need to weigh in. Gap 

### `docs/engineering-doc.md:570`

The doc builds the direct-play/direct-stream URL with a `api_key={token}` query parameter for authentication. In the spec: (a) GetVideoStream (`paths['/Videos/{itemId}/stream'].get`) declares no `security` array at all — no auth requirement is stated for this operation; (b) the string `api_key` occurs zero times anywhere in the 2.1MB spec, so it is not a declared parameter on this operation or any other; (c) the spec's only security scheme, CustomAuthentication, is `type: apiKey` delivered `in: header` under the name `Authorization`, not a query parameter named `api_key`.

- upheld: Doc quote confirmed verbatim at engineering-doc.md:570, in context (ResolveVideoPlaybackUseCase pseudocode for direct-play/direct-stream URL). Spec verified: paths['/Videos/{itemId}/stream'].get has no 'security' key (confirmed absent via direct key check), the spec has no global security block either, 'api_key' occurs 0 times anywhere in the 2.1MB spec, none of the operation's 52 declared query parameters is named api_key, and components.securitySchemes has exactly one scheme, CustomAuthentication, matching the specQuote verbatim: type apiKey, name Authorization, in header. No doc or 
- REFUTED: Doc is unambiguous at line 570 (no guess required), and corroborates the server-side param name itself at line 573 ("already contains api_key and playSessionId" in the server's own TranscodingUrl response) — the doc isn't inventing the name, it's echoing what 10.11.11 returns. This is Jellyfin's standard mechanism for URLs handed to native players (AVPlayer/VLCKit) that can't set the custom `MediaBrowser` Authorization header used elsewhere; the shared auth middleware accepts token via that header OR an api_key/ApiKey query param, which the attribute-driven OpenAPI generator doesn't c

### `docs/engineering-doc.md:572-573`

The doc treats the server-supplied TranscodingUrl as self-sufficient for auth (bare URL, no Authorization header attached in this branch) because it 'already contains api_key'. The spec's only declared auth mechanism for this exact GET operation is the header-based CustomAuthentication scheme (Authorization header); no query-string api_key parameter is defined anywhere in the operation, and the spec states no alternative (e.g. security: [] or an apiKey-in-query scheme) that would let a bare query string satisfy auth.

- upheld: Both quotes verified verbatim and in context. docs/engineering-doc.md:572-573 contains exactly the quoted else-if branch and comment. The spec's GET /Videos/{itemId}/master.m3u8 operation has security: [{'CustomAuthentication': ['DefaultAuthorization']}], 54 parameters with no 'api_key' entry, and components.securitySchemes.CustomAuthentication is {type: apiKey, name: Authorization, in: header} exactly as quoted. There is no global security block and CustomAuthentication is the only scheme defined anywhere in the spec, so no query-based api_key auth mechanism exists to justify the doc'
- REFUTED: Not blocking. Spec's parameter list under-documents Jellyfin's real auth: CustomAuthenticationHandler globally falls back to query-string api_key/ApiKey when no Authorization header is present -- standard Jellyfin/Emby behavior specifically for streaming URLs handed to native players (AVPlayer/VLCKit/HLS) that can't attach custom headers. TranscodingUrl's embedded api_key+playSessionId authenticates fine against 10.11.11 with no header; doc's comment is correct, not a guess. Spec-vs-runtime mismatch, not a doc gap.

### `docs/engineering-doc.md:470`

The spec explicitly defines a 403 response for GET /Videos/{itemId}/master.m3u8, but the doc's only status-code-to-MixtapeError mapping table has no entry for 403 (only 401, 404, 5xx, and specific URLErrors are covered), and no case in the MixtapeError enum (lines 246-256: serverUnreachable, notAJellyfinServer, invalidCredentials, quickConnectUnavailable, quickConnectExpired, sessionExpired, noPlayableSource, transport, decoding) obviously corresponds to a Forbidden response.

- upheld: Both quotes verified verbatim. docs/engineering-doc.md:470 (actual line 470 in "Status code mapping" paragraph) reads exactly as quoted, covering 401/404/5xx/specific URLErrors only. The spec's /Videos/{itemId}/master.m3u8 GET responses object contains exactly {200, 503, 401, 403} — confirmed via direct JSON extraction. Repo-wide grep for "403"/"Forbidden" across engineering-doc.md, architecture.md, and SPEC-DECISIONS.md returns nothing, so no other doc location resolves the gap. MixtapeError enum (lines 246-256) has no case that obviously maps a Forbidden response. Finding stands as s
- REFUTED: The status-code mapping table at engineering-doc.md:470 is scoped to JellyfinHTTPClient's typed get/post JSON calls, not to media stream URLs. The master.m3u8 URL is the server's own TranscodingUrl, handed straight to VideoPlayerControlling.load(url:headers:) (engineering-doc.md:482, 566-576) for VLCKit/AVPlayer to fetch natively -- it never goes through JellyfinHTTPClient's mapping logic. So there's no gap unique to 403 on this endpoint: every status the stream URL can return (401, 403, 503) sits outside that table equally, because the table doesn't govern this path at all. Where it 

### `docs/engineering-doc.md:441,470,481`

The doc's only status-code→MixtapeError mapping (line 470) is explicitly scoped to JellyfinHTTPClient's get/post calls, but the master.m3u8 URL for the transcodeHLS method is loaded directly by AVPlayerController/VLCPlayerController via VideoPlayerControlling.load(url:), never through JellyfinHTTPClient. Neither doc section states how a 401/403/503 the player's own networking encounters while streaming this URL gets translated into the MixtapeError passed to onFailure.

- upheld: All three quotes check out verbatim and in context: L441/L470 (JellyfinHTTPClient row, scoped to get/post + status-code mapping), L481/L482 (VideoPlayerControlling.onFailure and load(url:)). The transcodeHLS branch at L572-577 confirms source.transcodingUrl becomes a raw URL handed straight to load(url:), never routed through JellyfinHTTPClient. Grepped the whole doc for any AVPlayer/VLCKit error-to-MixtapeError translation (translat, catch, Error(, AVPlayerItem.Status, VLCMediaPlayerState, KVO, didFailToPlay) - zero hits outside the two cited HTTP-client/protocol lines. MixtapeError's
- REFUTED: MixtapeError already carries a documented catch-all: `.transport(String)` — "human-readable, already localised" (eng doc line 254). The line-470 status→MixtapeError table is explicitly scoped to JellyfinHTTPClient's URLSession-based JSON calls, where a clean HTTPURLResponse status code is available to switch on. AVPlayer/VLCKit don't hand back that shape for an HLS manifest/segment fetch — they surface an opaque NSError / player-state failure, not a parsed status code — so there is no equivalent status-code table for an implementer to reproduce or guess at for this path; wiring `onFai

### `docs/engineering-doc.md:593`

The spec types `container` as an array with no `style`/`explode` override, which under OpenAPI 3.0 defaults to `style=form, explode=true` — i.e. repeated `container=flac&container=alac&...` — but the doc serialises it as a single query value with the items comma-joined (`container=flac,alac,m4a,...`).

- upheld: Doc quote at engineering-doc.md:593 is verbatim and in context (Music streaming section). Spec confirms the container param for /Audio/{itemId}/universal.get is {"type":"array","items":{"type":"string"}} with no style/explode override, so OpenAPI 3.0 default applies: style=form, explode=true → repeated keys (container=flac&container=alac&...). The doc's example instead comma-joins (container=flac,alac,m4a,mp3,aac,wav,aiff), a genuine mismatch. Grepped the whole doc for "explode", "style=form", "comma-joined/separated" and other container= occurrences — nothing elsewhere resolves or jus
- REFUTED: eng-doc:593 gives a literal, unambiguous query string (container=flac,alac,m4a,mp3,aac,wav,aiff) for implementers to copy verbatim — no choice between comma-join vs repeated-key left to guess. CLAUDE.md frames the OpenAPI file as the API contract for shape, and the engineering doc as the source of truth for how to actually build calls; nothing elevates the spec's unstated array style/explode default over the doc's concrete worked example. SPEC-DECISIONS.md never addresses this (checked in full, 98 lines), but it doesn't need to since the doc already settles it.

### `docs/jellyfin-api.md:23`

docs/jellyfin-api.md identifies GET /Audio/{itemId}/master.m3u8 as 'the music HLS fallback' the client hits, but engineering-doc.md §8's actual music-streaming code builds the fallback by calling a completely different endpoint, /Audio/{itemId}/universal, with transcodingContainer/transcodingProtocol query params — it never constructs or calls /Audio/{itemId}/master.m3u8 for audio at all.

- upheld: Confirmed both quotes verbatim in context. jellyfin-api.md:23-26 literally names /Audio/{itemId}/master.m3u8 as "the music HLS fallback." engineering-doc.md's Music streaming section (lines 588-597) builds the fallback by constructing one URL to /Audio/{itemId}/universal with transcodingContainer=ts&transcodingProtocol=hls&audioCodec=aac, and calls that "the HLS fallback" (line 597) — master.m3u8 never appears anywhere in engineering-doc.md (grep confirms zero hits). Spec check confirms /Audio/{itemId}/master.m3u8 and /Audio/{itemId}/universal are two distinct real paths in openapi.jso
- REFUTED: engineering-doc.md §8 "Music streaming" (line 588-597) is self-contained and unambiguous: it gives the literal URL template to build for all audio playback — `/Audio/{itemId}/universal?...&transcodingContainer=ts&transcodingProtocol=hls&audioCodec=aac` — with no PlaybackInfo round-trip. The very next sentence (line 597) names this construction itself "The HLS fallback" and attaches the logging requirement to it directly, in the same paragraph as the code. An implementer writing the music-streaming code never needs to consult jellyfin-api.md at all; there is no separate instruction els

### `docs/engineering-doc.md:597`

Neither the engineering doc nor the spec gives the client any way to detect, from the response to the audio URL it builds, whether the server actually transcoded to HLS versus direct-playing the file. The 200 response is generic `audio/*` binary content in both cases — no distinguishing header, status code, or field — and the only non-200 case (302) is documented as an unrelated 'remote audio stream' redirect, not an HLS-fired signal. Unlike video, which reads SupportsDirectPlay/TranscodingUrl off a PlaybackInfo response before choosing a PlaybackMethod, the music path explicitly skips PlaybackInfo ('No PlaybackInfo round-trip for audio. Build the URL directly', engineering-doc.md line ~588) so it never receives the server-side capability data that would let it know which path was taken.

- upheld: Both quotes verified verbatim and in context. docs/engineering-doc.md:597 reads exactly as quoted, instructing logging when the HLS fallback fires but never specifying how the client would know it fired. The spec's /Audio/{itemId}/universal GET responses match exactly: 200 is audio/* binary (no distinguishing header/field), 302 is only 'Redirected to remote audio stream' (unrelated to HLS), plus 404/503/401/403 which are error paths, not transcode signals. Confirmed elsewhere in the doc that the video path gets TranscodingUrl/SupportsDirectPlay via PlaybackInfo (line 559) while line 58
- REFUTED: Verified the spec's claim is accurate (200 = generic audio/*, 302 documented as an unrelated remote-stream redirect) — but this doesn't block implementation. (1) The audio URL construction (engineering-doc.md:589-594) is fully specified with no guessed values; no call fails against 10.11.11. (2) The "log when it fires" language (lines 427, 597) is soft ("worth logging"), and is not tied to any acceptance criterion in §12 (13f verifies no-transcode via the Jellyfin admin dashboard, not client detection), not part of the 15-item scope list in §1, and has no named use case or test gating

### `docs/engineering-doc.md:215-221`

The Domain struct that is supposed to be the single source for building the /Sessions/Playing (and Progress/Stopped) JSON body has no field for CanSeek, yet the documented wire body requires CanSeek on every one of the three calls.

- upheld: Both quotes verified verbatim and in context. docQuote matches the PlaybackReport struct exactly (in the "Supporting value types" section, §4, which states "Every name used elsewhere in this spec is defined here. Nothing else gets invented") — it has itemID, mediaSourceID, playSessionID, position, isPaused, method, and no canSeek field. specQuote matches the documented wire body for all three /Sessions/Playing(/Progress|/Stopped) calls exactly, and it requires CanSeek. Grepped the whole doc plus architecture.md and SPEC-DECISIONS.md for CanSeek/canSeek: the string appears exactly once 
- REFUTED: CanSeek is optional in the real 10.11.11 OpenAPI schema (absent from 'required' on all three DTOs, and not even a property on PlaybackStopInfo), so omitting or hardcoding it cannot fail the call. Live TV/DVR is explicitly out of scope (eng doc line 33), so every session this app reports is on-demand VOD - CanSeek is always true, never a value that varies with PlaybackReport's other fields. The repository maps to the wire body and can hardcode "CanSeek": true as a literal alongside the field mapping, matching the doc's own example verbatim. A missing field on the domain struct is a min

### `docs/engineering-doc.md:603-612`

The doc never states a success status code or response shape for POST /Sessions/Playing; the spec returns 204 No Content with no body.

- upheld: Doc quote confirmed verbatim at engineering-doc.md:603-612 (table + shared JSON body, no status/response shape stated for any of the three calls). Spec quote confirmed verbatim: paths['/Sessions/Playing'].post.responses['204'].description == "Playback start recorded.", with no content/schema under 204 (only 401/403/503 also present, none with bodies either). Finding stands as written.
- REFUTED: SPEC-DECISIONS.md is silent on this, but engineering-doc.md itself already settles it. §5's PlaybackRepositoryProtocol (lines 296-298) declares reportStart/reportProgress/reportStopped as `async throws` with no return type — Void. Implementing a Void-returning method against the two HTTPClient.post overloads (line 456) is not a guess: with no assignment/context type forcing T, Swift's overload resolution picks the non-generic Void-returning `post<Body: Encodable & Sendable>(...) async throws` overload, since T cannot be inferred for the decoding overload in that call shape. That overl

### `docs/engineering-doc.md:470`

The spec's operation-level responses for POST /Sessions/Playing explicitly include 403 Forbidden, but the doc's status-code mapping table (the only place status codes are mapped to MixtapeError) has no branch for 403 and MixtapeError has no case that obviously fits it.

- upheld: Both quotes verified verbatim in context. Spec: POST /Sessions/Playing responses are exactly {204, 401, 403, 503} — 403/Forbidden is present as claimed (confirmed via direct extraction of d['paths']['/Sessions/Playing']['post']['responses']). Doc: engineering-doc.md line 470 verbatim matches, and it is the only status-code-mapping text in the whole file (grep for '403'/'Forbidden' in the doc returns nothing at all, and grep for MixtapeError shows no other mapping discussion). The mapping table branches only on 401 (auth vs elsewhere), 404/5xx, and three specific URLError cases — no 403
- REFUTED: Doc line 470 already establishes .transport as the fallback bucket for non-auth failure codes: 404 and 5xx (a whole range) both collapse to .transport with no distinct case per code. Swift also forces a default arm on any switch over raw Int status codes, so an implementer must write one regardless of docs. The obvious, non-guessing completion of the documented pattern is: any unlisted 4xx (incl. 403) also falls to .transport(String), same as 404 does. This is not a distinct 401-like semantic (no session/credential meaning), the call itself never fails against 10.11.11, and 403 is boi

### `docs/engineering-doc.md:607-613`

The doc says one identical JSON body (including IsPaused, CanSeek, PlayMethod) is sent for Start, Progress, AND Stop. The actual PlaybackStopInfo schema for POST /Sessions/Playing/Stopped has no IsPaused, no CanSeek, and no PlayMethod property at all, and declares additionalProperties:false — whereas PlaybackStartInfo and PlaybackProgressInfo (the schemas for the other two calls) both do carry CanSeek, IsPaused and PlayMethod. Stop's real schema instead exposes fields the doc never mentions: Failed (bool), NextMediaType, PlaylistItemId, NowPlayingQueue, SessionId, LiveStreamId, and a nested Item (BaseItemDto).

- upheld: Both quotes check out verbatim. docs/engineering-doc.md:607-613 does say "Body for all three:" then one JSON blob containing IsPaused/CanSeek/PlayMethod for Start/Progress/Stop. components.schemas.PlaybackStopInfo in docs/jellyfin-openapi.json has exactly the property set quoted (Item, ItemId, SessionId, MediaSourceId, PositionTicks, LiveStreamId, PlaySessionId, Failed, NextMediaType, PlaylistItemId, NowPlayingQueue), additionalProperties:false, and no IsPaused/CanSeek/PlayMethod fields at all. Finding is accurate as stated.
- REFUTED: additionalProperties:false is emitted uniformly on all three schemas (Start, Progress, Stop alike) — it's Swashbuckle's default for every C# DTO, not Stop-specific strictness, so it's not evidence the server rejects extra fields. Jellyfin's JSON layer (System.Text.Json, default UnmappedMemberHandling) ignores unmapped properties rather than erroring, and nothing is marked `required` in any of the three schemas — so sending the shared IsPaused/CanSeek/PlayMethod body to /Sessions/Playing/Stopped will not fail against 10.11.11, it just carries fields the server drops. Rubric test: whyBl

### `docs/engineering-doc.md:114`

§3's own dependency table declares MixtapeInfrastructure depends on MixtapeDomain; the engineering doc's own Appendix A (line 5: 'follow it literally') and architecture.md's copy of the same table both omit Domain from Infrastructure's dependencies, listing only Foundation and the third-party SDK.

- upheld: Confirmed genuine 3-way disagreement, not refuted. docs/engineering-doc.md:114 (§3 table, "Dependency edges declared in Package.swift" — line 108) reads exactly "| `MixtapeInfrastructure` | `MixtapeDomain`, VLCKit |". Appendix A's own table (engineering-doc.md line 828, table header at 824) reads "| `AppInfrastructure` | Network client, keychain, logging, third-party SDKs | Foundation, SDKs |" — no Domain. architecture.md (line 57, same table) has the identical "Foundation, SDKs" row. Appendix A is explicitly flagged authoritative/literal at engineering-doc.md:5 ("Appendix A is the arc
- REFUTED: SPEC-DECISIONS.md (98 lines, decisions 1-4) is silent on this — not settled there. But §7 of the engineering doc resolves it unambiguously without needing SPEC-DECISIONS: `VideoPlayerControlling` (declared in §7, the Infrastructure section, line ~481) has `var onFailure: ((MixtapeError) -> Void)? { get set }`, and `JellyfinHTTPClient` (also §7) "maps status codes to `MixtapeError`". `MixtapeError` is defined in §4, Domain (line 246, inside the Domain section 127-267). So a concrete Infrastructure-layer protocol in the same document literally references a Domain-defined type in a membe

### `docs/engineering-doc.md:134`

ServerIdentity declares id/name/version as non-optional String, but the /System/Info/Public response schema (PublicSystemInfo) marks Id, ServerName, and Version all nullable.

- upheld: Doc quote verified verbatim at engineering-doc.md:134-139 (struct ServerIdentity with non-optional id/name/version). Spec quote verified verbatim: components.schemas.PublicSystemInfo.properties.Id/ServerName/Version all have {"type":"string","nullable":true}. Grepped engineering-doc.md for any nullable-mapping convention, Mapper nil-handling rule, or mention of PublicSystemInfo/ServerIdentity elsewhere (lines 248-280, 505) — none specifies what JellyfinAuthRepository's mapper does when Id/ServerName/Version come back null. SPEC-DECISIONS.md has no mention of ServerIdentity/PublicSystem
- REFUTED: Not blocking. MixtapeError already declares `.notAJellyfinServer` (eng doc line 248), a case with no other assigned trigger anywhere in the doc — it exists precisely for "this response doesn't look like a real Jellyfin server," which is exactly what a null Id/ServerName/Version on the one call that produces ServerIdentity means. An implementer isn't picking blind among three equally-weighted options; the taxonomy already supplies the obviously-named slot for this exact failure, unlike placeholder-substitution or a generic `.decoding`, which have no textual support here. Separately, nu

### `docs/engineering-doc.md:356`

SessionService's inline comment claims QuickConnectUIState has three cases (.idle, .waiting(code:), .failed), but the actual type definition in §4 Domain declares only two cases: .waiting(code:) and .failed(MixtapeError). There is no .idle case anywhere in the codebase's declared enum.

- upheld: Both quotes verified verbatim in docs/engineering-doc.md. Line 356 comment lists .idle/.waiting(code:)/.failed; the enum at lines 235-238 declares only .waiting(code:) and .failed(MixtapeError). Grepped whole doc — no second QuickConnectUIState declaration exists, no .idle case anywhere. Finding stands as given; quotes need no correction.
- REFUTED: Domain enum QuickConnectUIState (eng doc lines 235-238) is the sole declaration in the doc set -- architecture.md doesn't mention it and SPEC-DECISIONS.md is silent on it -- with exactly 2 cases: .waiting(code:) and .failed. The SessionService property at line 356 is typed QuickConnectUIState? (Optional). The stray ".idle" in that line's trailing comment is a loose paraphrase for nil, not a second competing type declaration. There's no compiler ambiguity: nil-as-idle is the only reading that type-checks against the one true enum, so no guess is required. This is also pure client-side 

### `docs/engineering-doc.md:360`

§6 says the Quick Connect polling Task sets `.quickConnectExpired` on expiry, and the preceding sentence's only settable state is `quickConnect: QuickConnectUIState?`. But `.quickConnectExpired` is a case of `MixtapeError` (§4), not of `QuickConnectUIState`, which only has `.waiting(code:)` and `.failed(MixtapeError)`. Assigning `.quickConnectExpired` directly to `quickConnect` does not type-check.

- upheld: Confirmed both quotes verbatim and in context. QuickConnectUIState (engineering-doc.md:235-238) has only .waiting(code:) and .failed(MixtapeError). MixtapeError (line 245-254) has case quickConnectExpired. Line 360 says "On expiry set `.quickConnectExpired`." with no qualifying wrapper — grepped the whole doc plus architecture.md and SPEC-DECISIONS.md for any other mention of quickConnectExpired or QuickConnectUIState; none exists to disambiguate. Assigning `.quickConnectExpired` directly to `quickConnect: QuickConnectUIState?` does not type-check; the doc never spells out `.failed(.qu
- REFUTED: Doc's own adjacent type defs settle it, no real guess needed. QuickConnectUIState (L235-238) has exactly 2 cases: .waiting(code:) and .failed(MixtapeError). MixtapeError (L244-254) has .quickConnectExpired. Only .failed can hold a MixtapeError, so 'set .quickConnectExpired' can only type-check as quickConnect = .failed(.quickConnectExpired). The inline comment '// sets quickConnect' on startQuickConnect() (L352) ties the whole QC flow, expiry included, to the quickConnect property, not the separate generic `error` field (used for sign-in/server errors). QuickConnectScreen is driven by

### `docs/engineering-doc.md:372`

SeriesService's declared method `episodes(seasonID:)` takes only a season ID, but the repository protocol it must ultimately call requires both `seriesID` and `seasonID`, and the underlying Jellyfin endpoint is `/Shows/{seriesId}/Episodes` — seriesId is a mandatory path component. §6 gives SeriesService no stored `currentSeriesID` or other state to recover the seriesID from a bare seasonID.

- upheld: Both quotes verified verbatim and in context (engineering-doc.md:372 and :288). Confirmed via docs/jellyfin-openapi.json that seriesId is a required path parameter on GET /Shows/{seriesId}/Episodes (seasonId is only an optional query filter) -- so the repository/endpoint genuinely cannot be called with seasonID alone. Checked MediaItem (line 158) for any field that could let SeriesService recover a seriesID from a season/episode item -- it has only seriesName (a display string, not an ID) and no parentID/seriesID field, so no implicit recovery path exists. Grepped the whole doc: line 3
- REFUTED: abbreviated shorthand in section 6, not a literal signature; the protocol at engineering-doc.md:288 (func episodes(seriesID: String, seasonID: String, session: UserSession)) is authoritative and unambiguous, matching the endpoint at line 524. LibraryService gets the same abbreviated treatment elsewhere in §6 (loadLibrary(id:) omits kind/page/session too), so this is an established doc convention, not a genuine conflict. The "per-series cache" phrase implies seriesID is already part of the design (as a cache key), so no hidden state is being invented. No guess about a value/shape/statu

### `docs/engineering-doc.md:470`

Line 470's rule is binary: 401 on 'the auth endpoints' always means .invalidCredentials. But that set is never enumerated or made mechanically derivable from the JellyfinHTTPClient signature (get(_:query:auth:) at lines 454-456 carries nothing marking a path as an 'auth endpoint'). Line 507 then shows the set isn't even uniform: on GET /QuickConnect/Enabled — one of the auth-table endpoints — a 401 means 'unavailable' (a third outcome distinct from both .invalidCredentials and .sessionExpired), not invalid credentials. The live spec compounds this: /QuickConnect/Enabled declares only 200 and 503 responses and has no security requirement, so it should not even 401 in the documented contract.

- upheld: Both quotes verified verbatim in docs/engineering-doc.md (line 470, line 507). Spec-checked /QuickConnect/Enabled: no security array, responses are only 200/503 — no 401 in the documented contract, confirming the third claim. Grepped whole doc for "auth endpoint" — line 470 is the only occurrence, so the set is genuinely never enumerated elsewhere, and the client signature (lines 454-456) carries no per-path marker to derive it mechanically. Finding stands as stated.
- REFUTED: Not blocking. Line 252's comment defines the split precisely: `.sessionExpired // 401 on an authenticated call` — i.e. a call carrying an established session token. `.invalidCredentials` is everything else in the 401 binary: a 401 while presenting credentials for the first time (sign-in, and every QuickConnect call, since §8 states none of them carry a token — QuickConnect only requires the stable-DeviceId auth header, not a session token). So `/QuickConnect/Enabled` mechanically falls in the `.invalidCredentials` bucket of the generic client mapping — no new MixtapeError case, no gue

### `docs/engineering-doc.md:460`

Section 7 states the Authorization header is the one auth format used on every request. But the direct-play/transcode stream URLs built in §8 (lines 570 and 592, the same URLs handed to VideoPlayerControlling.load(url:...)) put the access token in the query string as `api_key={token}` instead of the Authorization header — a second, undocumented auth format for exactly the requests that flow through §7's VideoPlayerControlling contract.

- upheld: Confirmed both quotes verbatim in docs/engineering-doc.md. Line 460: "**Authorization header** — one format, on every request including unauthenticated ones:". Lines 569-570 (specRef pointed at 570, but the `url =` statement begins at 569 — the two-line construct is one statement): "url = {base}/Videos/{itemId}/stream?static=true\n          &mediaSourceId={id}&playSessionId={psid}&api_key={token}". Same pattern repeats at line 573 (transcodingUrl "already contains api_key") and line 592 (music universal stream URL also carries `api_key={token}` in the query string). Grepped the whole d
- REFUTED: Not a real contradiction. The line-460 rule sits directly under the JellyfinHTTPClient struct contract (lines 448-459) and governs requests that client builds and sends — it never claims to govern raw stream URLs handed off to AVPlayer/VLCKit, which bypass JellyfinHTTPClient entirely. Section 8 gives an explicit, unambiguous, self-contained auth mechanism for exactly those two URLs (direct-play line 570, transcode line 592): the token rides in the query string as api_key, a real, documented Jellyfin auth path used specifically because native players like AVPlayer/VLCKit can't easily a

### `docs/engineering-doc.md:592`

Music streaming builds a bare URL with the token as an 'api_key' query parameter for an endpoint the spec both gates behind header-based CustomAuthentication and does not list an api_key parameter for at all — and this contradicts the doc's own §-external rule at line 460 ('Authorization header — one format, on every request including unauthenticated ones') and line 466 ('Do not use X-Emby-Authorization; Jellyfin is removing it'), which never mentions a query-string token alternative.

- upheld: Confirmed on primary sources, not refuted. engineering-doc.md:592 quote is exact. Spec /Audio/{itemId}/universal: security=[{CustomAuthentication:[DefaultAuthorization]}], full 18-param list has zero api_key entry. securitySchemes.CustomAuthentication = apiKey/header/Authorization only; grepped every path in the spec for an api_key-named parameter — 0 hits anywhere. Doc lines 460/466 (Authorization header, one format; no X-Emby-Authorization) confirmed real, sitting under §7 HTTP client contract — strictly it describes JellyfinHTTPClient JSON calls, not raw player URLs, so the "contrad
- REFUTED: Not blocking. Line 460's 'one format, on every request' is scoped to §7's JellyfinHTTPClient contract — the struct that wraps URLSession for JSON API calls. The §8 stream URLs (video at 570/573, audio at 592) are handed directly to AVPlayer/AudioPlayerController/VLCKit, which never go through JellyfinHTTPClient, so there's no contradiction, just two different transports for two different consumers. The doc is internally consistent about this: line 573 shows the server's own PlaybackInfo response embeds 'api_key' in the TranscodingUrl it hands back — Jellyfin itself uses query-string t

### `docs/engineering-doc.md:762`

AC11 requires episodes to be 'ordered correctly', but the episode-fetch call (engineering-doc.md:524, `GET /Shows/{seriesId}/Episodes?userId={uid}&seasonId={seasonId}&fields=Overview`) passes no sortBy at all, and the spec's sortBy enum for this exact endpoint has no IndexNumber or ParentIndexNumber option — unlike the album-tracks call on the very next line, which explicitly orders by `ParentIndexNumber,IndexNumber,SortName`. There is no documented sort field that guarantees episode-number order, and no stated reliance on (or evidence for) a server default order.

- REFUTED: The doc quote at line 762 is real and in context, and it's true the endpoint call at line 524 has no sortBy. But the finding's key claim is false: it quotes only the sortBy parameter's prose `description` field, which is a stale/incomplete summary. The parameter's actual `schema.enum` (allOf ref to components.schemas.ItemSortBy) for /Shows/{seriesId}/Episodes.get DOES include ParentIndexNumber, IndexNumber, and a dedicated AiredEpisodeOrder value — verified directly in docs/jellyfin-openapi.json. So a documented, legal sort key guaranteeing episode-number order exists for this endpoin
- REFUTED: Finding misreads the spec. The finding quotes only the parameter's stale prose `description` field, but the actual `schema.enum` for `sortBy` on `/Shows/{seriesId}/Episodes` (docs/jellyfin-openapi.json) DOES include `ParentIndexNumber`, `IndexNumber`, and even a purpose-built `AiredEpisodeOrder` value — the enum is the field an implementer/validator actually uses, not the copy-pasted description text. So passing `sortBy=ParentIndexNumber,IndexNumber` (mirroring the album-tracks call) is a legal, documented value for this endpoint, not a guess. No implementer needs to guess or would pr

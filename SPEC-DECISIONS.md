# SPEC-DECISIONS

Ambiguities in the spec set, resolved by the project owner. Binding on the build.
Where this file and any doc disagree, **this file wins** — including over
`docs/architecture.md`.

Decisions 1–3 were settled before the Phase 1 audit ran. The audit appends its
own resolved findings below.

---

## 1. Repository layout — engineering doc §3 wins

Three layouts existed: eng doc §3 (`Apps/` + `MixtapeKit/`), the
`feature/scaffolding` tree (`source/iOS`, `tests/iOS`, `uiTess/iOS`), and a
third on `main`.

**Decision: engineering doc §3.** One local SPM package, `MixtapeKit`, with six
library targets, plus two thin app targets under `Apps/`.

Rejected — the `source/iOS` layout, which makes the layers folders inside two
app targets. It contradicts settled decision D2, and it drops layer enforcement
to a grep script: a wrong cross-layer import compiles cleanly and is only caught
when `check-layer-imports.sh` runs. Under §3 the dependency edges are declared in
`Package.swift` and the compiler rejects the import outright, leaving the script
as a backstop for what the manifest cannot express rather than the only guard.

Rejected — `main`'s layout, which still carries the `Shared/` package from the
architecture decision D1 removed.

Consequence: build-order step 1 restructures the tree. `docs/architecture.md`
§"Project structure" has been rewritten to match; it previously described the
`source/iOS` layout and, under the repo's precedence rules, would otherwise have
outranked the engineering doc and sent the build the wrong way.

## 2. tvOS deployment target — 26.0

The project file sets `APPLETVOS_DEPLOYMENT_TARGET = 27.0` in some build
configurations and `TVOS_DEPLOYMENT_TARGET = 26` in others.

**Decision: 26.0 everywhere**, on one setting name, matching iOS 26.0 and both
`docs/architecture.md` and eng doc §2.

Rejected — standardising on 27.0. It would follow the local Xcode 27 toolchain,
but the docs say tvOS 26+, it splits the two platforms onto different baselines
for no stated capability, and the toolchain this project must stay compatible
with is Xcode 26.6. The 27.0 values read as an Xcode 27 default that was written
in rather than chosen.

A tvOS 26.5 simulator is installed, so the gates can run against it.

## 3. UI test directory — `uiTests/`, not `uiTess/`

**Decision: `uiTests/`.** Platform-split at the repository root:
`uiTests/iOS/`, `uiTests/tvOS/`.

`uiTess` was a typo that reached `docs/architecture.md` and the project file.
Fixing it now costs two files and a handful of `project.pbxproj` references;
fixing it after the run has generated test bundles, scheme references and target
memberships costs considerably more.

The physical rename is **part of build-order step 1**, not a separate change —
step 1 restructures the tree anyway, and renaming the directory twice is waste.
Engineering doc §3 does not say where UI tests live (its tree covers unit tests
only), so the placement above is this decision, not a reading of §3.

`docs/architecture.md` has been updated to `uiTests/` in both places.

The directory survives decision 4 — the targets stay wired up, so it still gets
renamed at step 1 even though nothing new lands in it this round.

## 4. XCUITest deferred — this round only

**Decision: no UI tests are written this round.** Engineering doc §11's
"one happy path per platform" and build-order step 11's XCUITest work are
deferred to a later round.

The `iOSUITests` and `tvOSUITests` targets stay wired into the project and their
two stub files stay on disk, excluded from the slice gate with
`-skip-testing:iOSUITests` / `-skip-testing:tvOSUITests`.

Rejected — deleting the UI test targets. A cleaner tree and marginally faster
builds, but re-adding XCUITest targets to an Xcode project is meaningfully
harder than deleting them was, and it means hand-editing `project.pbxproj` —
which is precisely where the `objectVersion = 77` pin is most likely to be lost
to an Xcode 27 rewrite. Keeping them costs two dead files.

Rejected — leaving the stubs in the test action. They are template stubs that
would pass, so they add no signal while booting a simulator on every gate of
every slice.

**Not deferred with them:** accessibility identifiers (eng doc §9), the
accessibility pass, and the Reduce Transparency pass. Step 11 bundles all four
together, but only XCUITest is being dropped. Identifiers are cheap written
beside the view and expensive retrofitted, and they are the seam the deferred
tests will attach to; acceptance criteria 13e and 15 depend on the other two
passes. Skipping them would make the deferral much harder to reverse than it
needs to be.

---

# Phase 1 audit decisions

Decisions 5–14 resolve the ten blocking ambiguities in `AUDIT-FINDINGS.md` §1
and the §2 verifier disagreement.

**Several were settled by probing the live server rather than by reading.** Where
that happened the evidence is recorded, because it is reproducible and because
two of these findings were ranked on a document disagreement that does not exist
in practice. Any future finding of the form "doc X and spec Y disagree" should be
checked against `http://localhost:8096` before it is treated as blocking.

## 5. Quick Connect initiate uses POST — finding 1 was not blocking

**Decision: `POST /QuickConnect/Initiate`.**

The finding claimed a doc/spec disagreement (doc says GET, spec declares POST
only) would produce "a 405/routing failure, breaking Quick Connect sign-in". It
does not. Both verbs return 200 with a valid `QuickConnectResult`:

```
GET  /QuickConnect/Initiate  → 200  {"Secret":"10588AF5…","Code":"426349",…}
POST /QuickConnect/Initiate  → 200  {"Secret":"7AEFD769…","Code":"866060",…}
```

(with a `MediaBrowser` Authorization header; without one both return 400.)

POST is chosen anyway because it is the verb the spec declares, so it is the one
guaranteed to survive a server upgrade. The undocumented GET is not relied on.

Recorded as a correction to `docs/engineering-doc.md:508`, not as a blocker.

## 6. Continue Watching uses `/UserItems/Resume` — finding 2 is real

**Decision: `GET /UserItems/Resume`.** `docs/engineering-doc.md:526` is wrong.

Confirmed against the server:

```
GET /Items/Resume?userId=…      → 400  {"errors":{"itemId":["The value 'Resume' is not valid."]}}
GET /UserItems/Resume?userId=…  → 200  {"Items":[],"TotalRecordCount":0,"StartIndex":0}
```

The audit's predicted failure mode was exactly right: `/Items/Resume` is
swallowed by the templated `/Items/{itemId}` route, which then rejects `Resume`
as a malformed item id.

Note for anyone probing this later: unauthenticated requests cannot distinguish a
real path from a fake one — `/Items/DefinitelyNotARealPath` also returns 401,
because auth middleware runs ahead of routing. Probe with a token.

## 7. One auth mechanism: the Authorization header, everywhere

**Decision: the `Authorization: MediaBrowser …` header carries the token on
every request, including stream URLs handed to AVPlayer and VLC. `api_key` is
not used anywhere.** `VideoPlayerControlling.load(headers:)` exists precisely to
carry that header into the player — that is the answer to finding 5, which asked
why the parameter was never explained.

Resolves findings 4 and 5 and the §2 verifier split together.

Both mechanisms work. Measured on `/Audio/{itemId}/universal`:

```
?api_key=<valid>    → 206      Authorization header → 206
?api_key=<invalid>  → 401      no auth              → 401
```

So `api_key` is genuinely honoured, not ignored — the spec is silent, not
contradictory, and the §2 blocking-lens judge was right that OpenAPI silence is
not evidence of rejection. The spec-lens judge was right about the facts.

Rejected — keeping `api_key` on stream URLs. It is the conventional Jellyfin
approach and simpler to hand to a player. But it means two auth mechanisms in one
app, puts the token in URLs and therefore in logs, and leaves `headers` as a
parameter with no purpose. One mechanism is worth the fiddlier `AVURLAsset`
options.

Consequence: `docs/engineering-doc.md:570` and `:592` drop `api_key={token}`.

### Carve-out: the server's `TranscodingUrl` is passed through verbatim

This decision governs URLs **the client constructs**. It does not govern
`MediaSource.TranscodingUrl`, which the server builds and hands back with auth
already embedded — as `ApiKey`, capitalised, alongside `PlaySessionId`, `Tag`,
`TranscodeReasons` and the codec parameters:

```
/videos/{id}/master.m3u8?DeviceId=…&MediaSourceId=…&VideoCodec=h264
  &PlaySessionId=d1a733a2…&ApiKey=78ac91…&Tag=d82a9686…&TranscodeReasons=…
```

It returns 200 exactly as given. Hand it to the player unmodified: do not strip
`ApiKey`, do not rebuild the query, and do not treat the embedded token as a
violation of this decision to be corrected. Adding the Authorization header to it
as well is harmless but unnecessary.

Note the casing. `docs/engineering-doc.md:573` says the URL "already contains
`api_key`"; the actual parameter is `ApiKey`. Both spellings authenticate on
requests the client builds, but only `ApiKey` appears in what the server returns.

## 8. `isWatched` — server `Played` when mapping, the 0.9 rule only during playback

**Decision: mapping a list or detail response sets `PlaybackState.isWatched`
from `UserData.Played` verbatim. The `position / duration >= 0.9` rule governs
only when active local playback reports an item watched to the server.**

Finding 10 framed these as competing sources for one field. They are not — they
apply at different moments, and the doc never says otherwise; it just never says
so explicitly either.

The deciding fact is that the third field the doc names does not exist:

> `PlayedPercentage` appears on **0 of 46 items**. The `UserData` keys this
> server actually sends are `PlaybackPositionTicks`, `PlayCount`, `IsFavorite`,
> `Played`, `LastPlayedDate`, `Key`, `ItemId`. `RunTimeTicks` is on the item, not
> in `UserData`.

So `docs/engineering-doc.md:530` lists a field that never arrives, and a mapper
written against it would compute from `nil`.

This also disposes of the nil-duration question the finding raised: the mapper
never computes a ratio, so it never needs a duration.

## 9. Unmapped 4xx → `.transport`. No new error case

**Decision: the status-code table gains a catch-all — any 4xx not explicitly
mapped becomes `.transport`.** 403 needs no case of its own.

Resolves finding 3, which correctly noted 403 is declared on 329 paths and has no
home in the mapping table.

It could not be provoked on this server: the admin key returns 200 on `/Items`,
a bogus userId returns 400, and `/Users/New` returns 415. 403 is spec boilerplate
for this deployment, though a non-admin user restricted from a library could
still produce one.

Rejected — adding `.forbidden`. More precise, and a real scenario for
multi-user Jellyfin, but it is an abstraction with no second conformer, no test
data and no distinct UI. The catch-all covers 400, 405, 415 and anything else
unforeseen at the same time; the user-facing result is the retry affordance from
acceptance criterion 16.

Rejected — mapping 403 to `.sessionExpired`. Semantically wrong: 403 means
authenticated but not permitted, so it would sign a user out of a working session
over a permissions problem.

## 10. Quick Connect initiate 401 → `.quickConnectUnavailable`

**Decision: a 401 from `/QuickConnect/Initiate` maps to
`.quickConnectUnavailable`, not `.invalidCredentials`.**

The spec documents that status on this operation as *"Quick connect is not active
on this server"* — identical in meaning to `/QuickConnect/Enabled`'s 401, which
the doc already carves out at line 507. The blanket "401 on auth endpoints →
`.invalidCredentials`" rule at line 470 gets a second named exception.

Rejected — the blanket rule. It keeps the table exception-free, but on tvOS,
where Quick Connect is the primary sign-in path per D5, it would show a
credentials error for a server-configuration problem the user cannot act on and
never entered credentials for.

## 11. `PlaybackPlan` carries the wire `PlayMethod` as its own field

**Decision: `PlaybackMethod` keeps meaning "which local player"
(`directAVPlayer` / `directVLC` / `transcodeHLS`). `PlaybackPlan` gains a
separate field holding Jellyfin's `PlayMethod` — `DirectPlay`, `DirectStream` or
`Transcode` — set from whichever of `supportsDirectPlay` / `supportsDirectStream`
was true at resolve time.**

Resolves finding 7. The resolution step is the only place that knows which was
true; the report step is where it is needed; nothing currently carries it across.

Rejected — reporting `DirectPlay` for anything non-transcode. One less field, and
it affects only the server's session dashboard rather than playback. But
acceptance criteria 6 and 7 are *verified by reading that dashboard*, so making it
report something untrue degrades the check those criteria depend on.

Rejected — widening `PlaybackMethod` to cover both axes. Two concepts in one enum
multiplies the case count and forces every "which player" switch to ignore half
of it.

## 12. `resolveVideo` returns sources; the use case selects the method

**Decision: `PlaybackRepositoryProtocol.resolveVideo` returns the media sources
from the `PlaybackInfo` response, not a finished `PlaybackPlan`.
`ResolveVideoPlaybackUseCase` turns those into the plan.**
`docs/engineering-doc.md:294` is corrected; `:563` stands.

Resolves finding 8, where §5 and §8 assigned method selection to different
layers.

The deciding argument is testability, not taste. Both `CLAUDE.md` and eng doc §11
require a unit test per `PlaybackMethod` branch plus `.noPlayableSource`, tested
without a server. If the repository returns an already-resolved plan, the use case
has no behaviour left to test and those tests can only assert a mock's plumbing —
which the same documents forbid.

Rejected — repository ownership with §8 deleted. Fewer types, but it puts
branching logic inside a stateless `Sendable` struct in `MixtapeData` and makes
`ResolveVideoPlaybackUseCase` a pass-through.

## 13. HomeScreen shows Continue Watching only — Recently Added is dropped

**Decision: "Recently Added per library" is removed from `HomeScreen`.** No
endpoint, use case, service property or cache is added for it.

Resolves finding 9. §1's fifteen capabilities include "Continue watching row on
Home" (#9) and never mention Recently Added, and §1 states that anything not
listed is out of scope. §9's screen table is the outlier, not the spec.

Rejected — building it against `/Items/Latest`. It would honour §9's wording, but
every supporting detail — method name, per-library cache shape, refresh trigger —
is undefined, so an unattended run would invent all three with nobody reviewing
the invention.

`docs/engineering-doc.md:631` loses the Recently Added column.

## 14. Video test data is required before the build runs

**Decision: the local library must contain video before build-order steps 6–8
begin.** At minimum: one `mp4/h264/aac` (exercises `.directAVPlayer`), one
`mkv/hevc/dts` (exercises `.directVLC`), and one source the device profile
rejects (exercises `.transcodeHLS`).

Not from the audit — the audit read documents and a spec, and this is not visible
from either. `isAVPlayerNative` and the resolve branches stay unit-testable from
their fixture table regardless — those are pure domain functions — but whether the
resulting URLs actually play cannot be established without files.

### Status — all three playback branches are reachable

The Movies library holds two items, verified end to end:

| Item | Container / codecs | Length | Branch | Stream check |
|---|---|---|---|---|
| Avatar: Fire and Ash | `mp4` · h264 1080p · **no audio track** | 20.8 s | `.directAVPlayer` | 206, `video/mp4` |
| F1 | `mkv` · h264 4K HDR · aac stereo | 48.4 s | `.directVLC` | 206, `video/x-matroska` |

`mkv` is on the VLC list by container regardless of codec, so the second item
exercises the branch VLCKit exists for. It also carries the audio track the first
one lacks, so the audio-codec half of `isAVPlayerNative` has real data behind it,
and at 48 s it is long enough for criterion 9's watch-30 s-and-resume.

**`.transcodeHLS` needs no exotic file.** Direct play is decided against the
`DeviceProfile` posted in the `PlaybackInfo` body, not against the file alone.
Posting a restrictive profile flips the same `mkv` to a transcode:

```
DirectPlayProfiles: [webm/vp9/opus only]  →  SupportsDirectPlay=false
                                              TranscodingSubProtocol=hls
                                              TranscodingUrl=/videos/…/master.m3u8
```

So criterion 8 is a test fixture, not a media-sourcing problem: post a profile
that excludes the source, confirm the branch resolves to `.transcodeHLS`, and
confirm the transcode session appears in the dashboard. The permissive profile
the app actually ships stays unchanged — that is the point of D4, and criteria 6,
7 and 13f all depend on it continuing to produce no transcode.

Remaining gap: **0 Series, 0 Episodes.** Criterion 11 (series → season → episode
ordering) stays unverifiable, and decision 27's `sortBy` fix has nothing to
confirm it against. Steps 6, 7 and 8 can all proceed.

---

# Section 3 decisions

`AUDIT-FINDINGS.md` §3 lists 52 findings the finder self-rated low and no judge
verified. They were worked through anyway. Decisions 15–25 are the ones that
change code shape; §26 disposes of the rest.

## 15. Concurrency settings go in `Package.swift`, not the project file

**Decision: `MixtapeKit/Package.swift` sets, on every one of the six targets:**

```swift
swiftSettings: [
  .defaultIsolation(MainActor.self),
  .swiftLanguageMode(.v6),
]
```

This is the most consequential item in §3 and it was rated low.

§2 says `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
`SWIFT_APPROACHABLE_CONCURRENCY = NO` are set "at project level". §3 then puts
all six layers in an SPM package. **Xcode build settings do not propagate into
SPM package targets.** Setting them on the project and stopping there leaves
every layer target compiling without MainActor-by-default — silently. Nothing
fails, nothing warns, and the invariant `CLAUDE.md` calls non-negotiable simply
is not in effect.

It lands in build-order step 1, and it gets more expensive with every slice built
on top of the wrong assumption.

The app targets keep the project-level settings; those do apply to them.

## 16. No macOS target, and Appendix A's baseline does not override that

**Decision: iOS and tvOS only.** Appendix A's "MacOS 26+" line — duplicated
verbatim into `docs/architecture.md:35` — is generic template text carried over
from trimr, not a project requirement.

Recorded explicitly because `CLAUDE.md` names Appendix A as the authoritative
architecture template, so an unattended run could reasonably read "MacOS 26+ is a
required baseline" as binding and add a target. §2 and D-level scope both say no
macOS; this decision outranks both appendix copies.

## 17. Accessibility identifiers: one file per screen's enum

**Decision: one enum per file, named for the enum —
`WalletIdentifiers.swift`, `MovieDetailIdentifiers.swift`, and so on.** §9's
single `Identifiers.swift` holding many enums is overruled by the project-wide
one-type-per-file rule.

Rejected — keeping one file with an exception. Easier to scan, and identifier
enums are trivial. But an unattended run that finds one sanctioned exception to a
stated absolute has precedent for inventing a second.

Identifiers remain in scope this round even though XCUITest does not (decision 4).

## 18. `AVPlayerController` presents via `VideoPlayer` (AVKit)

**Decision: `makeView()` returns a `VideoPlayer`-backed representable.** Line 443's
`AVPlayerLayer` description is corrected.

`VideoPlayer` supplies transport controls, Picture in Picture and AirPlay, which
§2's capabilities list already requires the app to declare. Building those by
hand against a raw layer is work the platform will do.

Rejected — `AVPlayerLayer` + `UIViewRepresentable`, which would give both players
an identical representable shape and full presentation control, at the cost of
reimplementing the transport UI twice.

`VLCPlayerController` still presents its own view; `VideoPlayerControlling` keeps
Presentation seeing only `AnyView`.

## 19. Playback reporting is three use case types

**Decision: `ReportPlaybackStartUseCase`, `ReportPlaybackProgressUseCase`,
`ReportPlaybackStoppedUseCase`.** The single `ReportPlaybackUseCase` with three
methods is dropped.

§5's own rule — one type per use case, one `callAsFunction`/`execute` entry point
— is stated two paragraphs above the table that breaks it. Three thin structs
sharing a repository cost almost nothing and each gets its own test.

Rejected — one type with an `action:` parameter. It satisfies the rule literally
while collapsing three different payload shapes into one signature.

## 20. Wallet grid keys off horizontal size class; AC13a is reworded

**Decision: the grid stays keyed to SwiftUI horizontal size class.**
Acceptance criterion 13a becomes: *3×3 on iPad and on regular-width iPhones in
landscape; standard iPhones stay 2×2 in both orientations.*

AC13a as written asserts every iPhone reaches 3×3 on rotation. It does not — a
standard iPhone stays `compact` width in landscape; only Plus/Max-class devices
reach `regular`. The criterion was written from an assumption about rotation that
the layout rule never supported.

Rejected — keying the grid to device orientation to preserve the criterion as
written. It fights SwiftUI's adaptive layout model and has no sensible meaning in
iPad multitasking.

The fixed-page, no-reflow-mid-page requirement is unaffected.

## 21. `PollQuickConnectUseCase` performs the token exchange itself

**Decision: it polls `GET /QuickConnect/Connect` until `Authenticated` is true,
then calls `POST /Users/AuthenticateWithQuickConnect` with the secret and returns
the `UserSession?` its signature already declares.**

`/QuickConnect/Connect` returns no `AccessToken` and no `User` — the use-case
table's `UserSession?` return type is unreachable from that endpoint alone. Two
server calls behind one entry point is not a rule violation; the rule governs
entry points, and "sign in by Quick Connect" is one outcome.

Rejected — splitting poll and exchange into two use cases. Cleaner single
responsibility per type, but it moves the sequencing into `SessionService`, which
is meant to hold state rather than orchestrate call order.

The injected clock still drives polling; no test sleeps.

## 22. Supported server version is 10.11.x, not 10.10+

**Decision: the definition of done reads 10.11.11. The README states 10.11 or
newer, untested below.**

§1's "10.10+" is a claim about servers the project has never run against, and it
sits in the same document set as the methodology note explaining that two Jellyfin
versions differed by 22 paths — two of them on the critical path. The same
reasoning that forced re-pulling the spec applies to the compatibility range.

Rejected — keeping 10.10+ with a runtime version check and a warning. It would
preserve the broader claim, but the check and its UI are new scope neither doc
specifies.

## 23. Music HLS fallback is in scope

**Decision: capability 12 is amended to name the HLS fallback explicitly.**
`/Audio/{itemId}/universal` requests natively-decodable containers so a correctly
tagged library direct-streams every time; `/Audio/{itemId}/master.m3u8` fires only
for genuine exotica, and logs the item id at `.info` on the `playback` category
when it does.

§1's capability list omitted it while §8, `CLAUDE.md` and `jellyfin-api.md` all
treat it as real — and it is one of the two endpoints whose absence from the
12.0.0 spec justified decision-era re-pulling. §1 was the outlier.

Rejected — direct stream only. One undecodable file would fail an album outright,
and the transcode's diagnostic value (it means a file is mistagged) would be lost.

## 24. `QuickConnectState` gains `.idle` — see also decision 28

**Decision: the enum is `.idle`, `.waiting(code:)`, `.failed`.** §9's property
comment described three states; §4's enum defined two.

Rejected — an optional property with `nil` meaning idle. More idiomatic for
"nothing in progress", but it makes every read an unwrap and turns the preview
state set into cases-plus-nil rather than one closed set.

## 25. Image mapping, settled against the server

All four were probed. `MediaItem` image fields map as follows:

| Field | Source | Evidence |
|---|---|---|
| `primaryImageTag` | `ImageTags["Primary"]` | album returns `ImageTags: {"Primary": "f9a46…"}`; the scalar `PrimaryImageTag` is `null` |
| `backdropImageTag` | `BackdropImageTags.first` | it is an array, and returns `[]` here — the empty case is normal, not exceptional |
| track album art | `AlbumId` + `AlbumPrimaryImageTag` | a track's own `ImageTags` is `{}` while both album fields are populated — the fallback is **mandatory**, not a nicety |
| auth on image requests | none | `GET /Items/{id}/Images/Primary` with no auth returns 200 |

The last row disposes of the §3 finding that `ImageService` cannot reach
`AuthContext` without a layer violation. It never needs to: image requests are
unauthenticated, so `MixtapeServices` requires nothing from
`MixtapeInfrastructure` and `check-layer-imports.sh` stays satisfied. §8's "send
it anyway for consistency" is dropped — it is what created the impossible
requirement.

`ImageURLBuilder` returns `nil` when the relevant tag is `nil` rather than
building a URL that 404s. The `maxHeight` value goes in the **`maxHeight`** query
key, not `fillHeight` — both are accepted by the server, but they mean different
things and the parameter is named for the former.

## 26. Remaining §3 findings — dispositions

No further decisions needed. Corrections apply to the named file.

| Finding | Disposition |
|---|---|
| `fields=` on `/Items/{itemId}` "not declared" | **No change.** Server accepts it and returns `MediaSources`. The spec under-declares the parameter. |
| Album tracks paged or not | **No change.** `tracks(albumID:)` returns a plain array by design — §1.1 needs the whole album, never a page. |
| `userId` optional on `/UserItems/Resume` | **No change.** Send it regardless, as with every other user-scoped call. |
| Episodes discard `TotalRecordCount` | **No change.** Seasons are small; the unpaged `[MediaItem]` return is deliberate. |
| 503 + `Retry-After` on `/System/Info/Public` and progress reports | **`.transport`** per decision 9. `Retry-After` is not honoured in V1. Progress failures are swallowed regardless. |
| 400 "Missing token" on AuthenticateWithQuickConnect | Covered by decision 9's unmapped-4xx catch-all. |
| 403 on progress / stopped endpoints | Covered by decision 9. |
| Auth header on `/QuickConnect/Enabled` | **Send it.** The spec models the call as unauthenticated; sending the header is harmless and keeps one code path. |
| `deviceId` missing from the video stream URL | **Add it.** The server uses it to stop encoding processes for that device, and the audio URL already sends it. |
| `MovieLibraryShelf` named in §3, absent from §9 | **Keep the name.** §9's tvOS catalogue gains the row. |
| `SeriesLibraryGrid` has no column spec | **Mirror `MovieLibraryGrid`** — same generic `/Items` call, same layout rules. |
| `RootScreen` / splash absent from §9 tables | **Add both.** `.signedOut` routes to `ServerEntryScreen` first, then `SignInScreen` or `QuickConnectScreen`. |
| §9.1 names `CMMotionManager` directly | **Use `DeviceAttitudeReader`.** §7 built the abstraction so the sleeve never sees CoreMotion. |
| tvOS "same information architecture" but 5 tabs vs 4 | **Keep 5 tvOS tabs** (Home, Movies, Shows, Music, Settings). The prose is wrong, not the structure. |
| §1.1 "applies to iOS only" | **Only consequence 3 is iOS-only.** The queue-is-one-album invariant and the absence of shuffle/repeat/append are shared — `MusicPlayerService` is one type. tvOS has no wallet to return to, which is all the sentence meant. |
| `Mock*` in §11 vs `Stub*` rule | **`Stub*` in test targets, `Mock*` in the main target for previews.** §11 is corrected. |
| `App.swift` vs `MixtapeApp.swift` | **`MixtapeApp.swift`** — filename matches the `MixtapeApp` type, per the one-type-per-file rule. |
| Build order has two step 11s | **Renumber.** tvOS presentation is 11; accessibility and Reduce Transparency become 12. XCUITest is deferred (decision 4). |
| Preview states `{empty, nil, failure}` vs `{loaded, empty, failure}` | **`{loaded, empty, failure}`** — §9's project-specific list wins over the generic template. |
| Appendix A's SwiftData / `AppData/Persistence/` carve-out | **Not applicable.** No SwiftData in V1; the only caching is in-memory. Generic template text. |
| Appendix B `-scheme Mixtape` / `MixtapeTV` | **Schemes are `iOS` and `tvOS`** — the only two that exist. Appendix B is corrected. |
| Appendix B hardcodes `OS=26.0` | **Resolve a simulator at runtime.** Already a `CLAUDE.md` rule; no 26.0 runtime is installed. |
| Appendix B omits `-skip-testing` | **Add both flags** per decision 4. |
| Appendix C's `/api-docs/swagger` | Already corrected — the JSON is at `/api-docs/openapi.json`. |
| Appendix C "deprecated `/Users/{userId}/…`" | Both forms return 200 and neither is flagged `deprecated` in 10.11.11. **Use the query form anyway** — it is the documented project preference and the path form is deprecated upstream. |
| `architecture.md` `AppInfrastructure` dependency row | **Follow eng doc §3:** `MixtapeInfrastructure` depends on `MixtapeDomain` and VLCKit. |
| `architecture.md` verify commands | **Follow `CLAUDE.md`'s gate criteria** — both schemes, runtime simulator, `-skip-testing` flags. |
| XCUITest per-platform vs per-screen | Moot this round (decision 4). When it returns: **one happy path per platform.** |
| §11's XCTest carve-out vs `CLAUDE.md`'s "never XCTest" | Both are right in their scope. XCTest is permitted **only** for XCUITest, which is deferred — so no XCTest is written this round. |

---

# Section 4 review — refutations examined

All 40 refuted findings were re-read. Most refutations hold. Decisions 27–31
cover the ones that do not, or that were refuted as "not blocking" while still
leaving a real correction unmade. Three were settled by probing the server.

Refutations accepted without change, for the record: the `api_key` group
(superseded by decision 7, and both mechanisms verified working); every 403
finding (decision 9 reached the same conclusion the judges did); `enableUserData`
omission (verified — 46 items returned `UserData` with the parameter never sent);
`container` comma-joining (verified — `container=flac,alac,…` returns 206, so the
doc's literal string works despite the spec's array default implying repeated
keys); `CanSeek` absent from `PlaybackReport` (hardcode `true`; Live TV is out of
scope so it never varies); `PlaybackInfoResponse.ErrorCode` (not read — the
"first usable MediaSource else `.noPlayableSource`" rule covers every cause);
and `MixtapeInfrastructure` depending on `MixtapeDomain` (already in §26).

## 27. Episodes are sorted explicitly — the refutation stopped one step short

**Decision: the Episodes call becomes**
`GET /Shows/{seriesId}/Episodes?userId={uid}&seasonId={sid}&sortBy=ParentIndexNumber,IndexNumber&fields=Overview`.

Both lenses refuted this finding on the grounds that the sort keys the finder
claimed were missing do exist — the finder had read the parameter's stale prose
`description` instead of its `schema.enum`, which does contain
`ParentIndexNumber`, `IndexNumber` and `AiredEpisodeOrder`.

That is correct and it disposes of the finder's stated reason. It does not
dispose of the finding. The doc's call at `:524` still passes **no `sortBy` at
all**, and acceptance criterion 11 requires episodes to be "ordered correctly".
Proving a legal sort key exists is not the same as using one; the refutation
established that the fix is available and then closed the finding.

The album-tracks call on the very next line already sorts explicitly. Episodes
now match it.

## 28. `quickConnect` is non-optional and the enum carries `.idle`

**Amends decision 24.** The property is `var quickConnect: QuickConnectUIState`
— not optional — and `QuickConnectUIState` has `.idle`, `.waiting(code:)`,
`.failed(MixtapeError)`.

Decision 24 was made before this section was read. A §4 refutation notes the
property is currently typed `QuickConnectUIState?` and argues `.idle` is just a
loose paraphrase for `nil`. Both readings are defensible on their own; together
they are not — adding `.idle` while keeping the optional gives two spellings of
the same state, which is worse than either choice alone.

One closed set of states, exhaustively switchable, matching the `#Preview`
requirement.

## 29. Expiry sets `.failed(.quickConnectExpired)`

**Decision: `quickConnect = .failed(.quickConnectExpired)`.**

§6 line 360 says "on expiry set `.quickConnectExpired`", which does not
type-check — `.quickConnectExpired` is a `MixtapeError` case, and
`QuickConnectUIState` can only hold one via `.failed`. The refutation is right
that only one reading compiles. Recorded so the implementer does not have to
re-derive it.

The client-side 5-minute timer remains the only trigger. A 404 from
`/QuickConnect/Connect` mid-poll maps to `.transport` per the generic rule and
terminates the poll — errors are terminal everywhere else in the doc, and nothing
retries.

## 30. `SeriesService.episodes(seriesID:seasonID:)`

**Decision: the service method takes both ids**, matching
`LibraryRepositoryProtocol.episodes(seriesID:seasonID:session:)` at `:288` and
the endpoint's required `seriesId` path component.

§6's `episodes(seasonID:)` is refuted as abbreviated shorthand, consistent with
`loadLibrary(id:)` elsewhere in the same section. Accepted — but written down,
because a bare `seasonID` cannot reach the endpoint and §6 gives `SeriesService`
no state to recover the `seriesID` from.

## 31. `.notAJellyfinServer` fires on a null-field identity response

**Decision: `ValidateServerUseCase` throws `.notAJellyfinServer` when
`/System/Info/Public` returns without `Id`, `ServerName` or `Version`.** The DTO
types all three as optional; `ServerIdentity` keeps them non-optional and the
mapper is where the assertion is enforced.

Two findings were refuted separately — one that `.notAJellyfinServer` has no
stated trigger anywhere, one that `ServerIdentity`'s non-optional fields
contradict a schema that marks all three nullable. Each refutation gestures at
the other's answer, and neither states it. Together they are one decision, and it
had not been made.

## 32. A missing item returns 500, not 404

**Decision: no change to the mapping — but the behaviour is recorded.**

A §4 refutation argued that GetItem's undeclared 404 is harmless because
"404/5xx → `.transport`" covers it. The conclusion holds; the premise was
untested. A well-formed but non-existent GUID returns:

```
GET /Items/00000000000000000000000000000001  → 500  "Error processing request."
```

Not 404. It lands in `.transport` either way, so nothing changes — but "item not
found" is indistinguishable from a genuine server fault on this server, which
matters if anyone later wants a distinct not-found affordance. Do not write a
`404`-keyed branch expecting it to fire.

Two other §4 premises were tested and hold:

- `POST /Users/AuthenticateByName` with bad credentials returns **401**, though
  the spec declares only 200 and 503. The doc's `401 → .invalidCredentials` is
  correct and the spec is simply incomplete.
- `POST /Sessions/Playing/Stopped` returns **204** for both the doc's shared
  three-call body and the schema-exact body. The extra `IsPaused`, `CanSeek` and
  `PlayMethod` fields are ignored, so one shared body for all three reports is
  safe.

---

# Phase 2 decisions

Raised by the Phase 2 plan review, before the slice set was written.

## 33. Decision 7 is provisional until a spike proves both players can carry the header

**Decision: the spike blocking video playback asks the question for *both*
players and runs before slice 006, not 007** — "can `AVPlayerController` and
`VLCPlayerController` each send `Authorization: MediaBrowser …` on a stream
request?"

**The fallback is pre-authorised, so an unattended run does not stall on it:** if
a player cannot carry the header, that player's stream URLs carry `ApiKey` in the
query string instead, and decision 7 is amended to a per-player split. Record
which player took the fallback and why in the spike's Result section.

Decision 7 was made on server-side evidence — both mechanisms authenticate, which
is true and was measured. It says nothing about whether the *client* can deliver
a header, and that is a different question with a different answer per player:

- `AVURLAssetHTTPHeaderFieldsKey` is not public API. The documented route for
  injecting auth into AVPlayer is `AVAssetResourceLoaderDelegate`, which for HLS
  means a custom URL scheme and reimplementing manifest fetching.
- libvlc's support for arbitrary request headers is likewise not a documented
  media option.

The audit's blocking-lens judge said exactly this when it refuted the `api_key`
findings — "Jellyfin's standard mechanism for URLs handed to native players
(AVPlayer/VLCKit) that can't set the custom `MediaBrowser` Authorization header".
That was read as a claim about the server, checked against the server, and
accepted on those terms. It was a claim about the client.

**Do not reach for the private `AVURLAsset` key to satisfy decision 7.** Taking
the `ApiKey` fallback is correct; shipping a private API to preserve a decision
is not.

Slice 006's plan asserts header delivery "through AVURLAsset HTTP header
options". That assertion is what the spike tests, not a settled input.

## 34. Music playback reports to the server

**Decision: `MusicPlayerService` calls the same three report use cases as
`VideoPlaybackService`** — start, progress, stopped.

§1 capability 13 reads "Report playback start / progress / stop to the server"
with no video qualifier, and §1 is the scope authority. §6's assignment of
reporting to `VideoPlaybackService` describes where the video path's reporting
lives, not a restriction of capability 13 to video.

Rejected — video only. It halves a listed capability, leaves music invisible in
Jellyfin's session list and play counts, and makes AC13f's "no transcode session
in the dashboard" harder to read when no music session appears there at all.

The three use cases already exist from build step 8, so this is wiring, not new
machinery. **The §1.1 invariants suite gains cases** covering it: reporting must
not introduce a cross-album queue, must not fire for a track that was never
played, and `finishedAlbumID` must still fire exactly once with reporting
enabled.

## 35. A FLAC album is added before the run

**Decision: the library gains a FLAC album.** AC13f stands as written.

Measured: all 46 tracks are `m4a`/`alac`. There is no FLAC.

ALAC would demonstrate the criterion's substance — a lossless album
direct-streaming with no transcode — but FLAC is the container the
`/Audio/{id}/universal` list leads with, and the one most likely to appear in a
real library. Proving the format the app asks for first is worth one album.

Rejected — rewording AC13f to ALAC, which would leave the leading container
unproven. Rejected — letting the run substitute and record it, which produces a
slice claiming a criterion it demonstrated with other data.

Until the album exists, AC13f is unverifiable and no slice may claim it — the
same rule decision 14 applies to criterion 11.

## 36. `MixtapeServices` depends on `MixtapeInfrastructure`

**Decision: `Package.swift` adds the edge `MixtapeServices` →
`MixtapeInfrastructure`, and `check-layer-imports.sh` permits that import.**
Lands in build-order step 1.

Engineering doc §3's table gives Services only `MixtapeUseCase` and
`MixtapeDomain`, yet §6 has `VideoPlaybackService` own a `VideoPlayerControlling`
and `MusicPlayerService` own an `AudioPlayerController`, and §7 places both in
`MixtapeInfrastructure`. The two sections disagree and nothing resolved it.

`VideoPlayerControlling.makeView() -> AnyView` pins the protocol to a module that
imports SwiftUI, so it cannot move to `MixtapeUseCase` or `MixtapeDomain`, and
`MixtapeInfrastructure` cannot import `MixtapeServices` to conform.

Rejected — declaring the player protocols in `MixtapeServices` and adding the
conformances as extensions in the app target. Keeps §3's table intact, but it is
retroactive conformance across two imported modules and earns a compiler warning.

Rejected — a seventh target holding just the player protocols, imported by both
Services and Infrastructure. It would preserve §3's table exactly, but D2 settled
the architecture at six library targets, and adding a target is a larger
departure than adding an edge.

Rejected — splitting `VideoPlayerControlling` into a SwiftUI-free control
protocol in `MixtapeUseCase` and a view-providing protocol in
`MixtapePresentation`. Architecturally the cleanest of the four, and it would
need no new edge — but `CLAUDE.md` states Presentation sees
`VideoPlayerControlling` *and* an `AnyView` through one protocol, and splitting it
puts view construction back in Presentation, which is where VLCKit isolation
starts to leak.

`MixtapeServices` still may not import `MixtapeData`. `MixtapePresentation`'s
forbidden imports are unchanged.

**The edge is wider than the need.** It gives Services sight of
`JellyfinHTTPClient`, `KeychainStore` and VLCKit as well as the player
controllers, and no grep can tell an intended import from an unintended one. The
rule is narrower than the edge: **`MixtapeServices` imports
`MixtapeInfrastructure` for the player controllers and for nothing else.** A
service that reaches for the HTTP client or the keychain directly is a defect the
layer script will not catch.

## 37. The start report moves to slice 006 — the dashboard gates need it

**Decision: `ReportPlaybackStartUseCase` lands in build step 6, not 8.** Progress,
stopped and resume stay in step 8.

Every dashboard-based acceptance check depends on it, which was not visible from
the docs. Measured: with a transcode genuinely running and the `master.m3u8`
fetched, `/Sessions` reports nothing —

```
GET /Sessions → 2 sessions, NowPlayingItem: None, PlayMethod: None,
                TranscodingInfo: None
GET /Videos/ActiveEncodings → 405
```

`TranscodingInfo` hangs off a session's `NowPlayingItem`, and that only exists
once `POST /Sessions/Playing` has been sent. There is no other endpoint exposing
active transcodes.

Two consequences the slice set had wrong:

- **"No `TranscodingInfo` on the session" is unfalsifiable** before reporting
  exists. It passes whether or not the app is transcoding, so as a gate for AC6
  and AC7 it cannot fail.
- **AC8's gate expects `TranscodingInfo` present**, which cannot happen in step 6
  without the start report. It would fail against a correct transcode
  implementation — and an unattended run reading that failure would begin
  altering working code.

Moving one of decision 19's three use cases forward is the smallest change that
makes steps 6 and 7 gate on their own behaviour. A slice whose acceptance is
deferred two slices later is not gated; it is only sequenced.

AC6, AC7 and AC8 are therefore claimed in full by steps 6 and 7, not split
across 6/7 and 8.

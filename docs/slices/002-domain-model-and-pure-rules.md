---
slice_id: "002"
title: Domain model and pure rules
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "001", type: hard, note: "needs MixtapeDomain and MixtapeDomainTests targets to exist, with the .defaultIsolation(MainActor.self) / .swiftLanguageMode(.v6) settings and the layer-import script in place" }
previous_slice: "001"
next_slice: "003"
parent_slice: none
covers: []
created: 2026-09-03
---

# 002 — Domain model and pure rules

← [previous](001-package-skeleton-and-gates.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](003-http-client-keychain-logger.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Every §4 entity, value type and error case compiles in `MixtapeDomain` against Foundation alone, and the pure rules the rest of the build depends on — native-player detection, tick conversion, the watched threshold, display-title formatting — exist as tested functions before any layer above Domain has something to call.

## 2. Business Value & Priority

Nothing above Domain can compile without these types, so this is the narrowest possible slice that unblocks everything else — P0, and first in the ordering after the skeleton. It is not a rung on a ladder: the domain model is written once for V1 and every later slice extends it by addition, not replacement.

## 3. Scope

**In scope:**
- `ServerIdentity`, `UserSession`, `MediaKind`, `Library`, `LibraryKind`, `MediaItem`, `PlaybackState` exactly per §4, with `ServerIdentity.id` / `.name` / `.version` non-optional (decision 31 — the optionality lives in the Data-layer DTO, not here; `ValidateServerUseCase` throwing on a null field is slice 004's concern).
- `PlaybackMethod` (`.directAVPlayer`, `.directVLC`, `.transcodeHLS`) and `PlaybackPlan`, with `PlaybackPlan` carrying both `method: PlaybackMethod` and a second field for the wire `PlayMethod` (decision 11).
- `PlayMethod` as its own `Sendable, Equatable` enum: `.directPlay`, `.directStream`, `.transcode` — the server's vocabulary, kept distinct from `PlaybackMethod`'s "which local player" vocabulary per decision 11.
- `PageRequest`, `Page<Element>`, `QuickConnectHandshake`, `PlaybackReport` (also gaining the wire `PlayMethod` field, per decision 11's report-time need), `LoadState<Value>`, `PlayerStatus`, `ImageKind`.
- `QuickConnectUIState` as `.idle`, `.waiting(code: String)`, `.failed(MixtapeError)` — three cases, no optional wrapper (decisions 24 and 28).
- `MixtapeError` exactly as §4's eight cases plus `.decoding`; no `.forbidden` case (decision 9).
- `MediaSourceCandidate`: a new Domain value type, not named in §4, needed because decision 12 moves method selection out of the repository and into `ResolveVideoPlaybackUseCase` — the repository has to hand the use case something. Fields: `id: String`, `container: String`, `videoCodec: String?`, `audioCodec: String?`, `supportsDirectPlay: Bool`, `supportsDirectStream: Bool`, `transcodingUrl: String?`, `runTimeTicks: Int64?`. This is the shape `PlaybackRepositoryProtocol.resolveVideo` will return in slice 006; this slice only defines the type.
- `isAVPlayerNative(container:videoCodec:audioCodec:) -> Bool`, a pure function in Domain, per the §8 fixture rule: container ∈ `mp4, m4v, mov` and video codec ∈ `h264, hevc` and (audio codec is `nil` or ∈ `aac, mp3, alac, ac3, eac3`) → `true`; anything else → `false`. A `nil` audio codec means no audio track, which AVPlayer plays (decision 39); the container check still keeps `mkv` on VLC.
- `Duration+Ticks.swift`: `Duration.ticks` and `Duration(ticks:)` (or equivalent init), `ticks = seconds * 10_000_000`, used nowhere outside Domain and Data.
- `MediaItem.displayTitle`: episode → `"S2E4 · Title"` (from `parentIndexNumber` / `indexNumber` / `name`), track → `"3. Title"` (from `indexNumber` / `name`), everything else → `name`.
- `PlaybackState.isWatched` as a stored `Bool` — set by the mapper from the server's `UserData.Played` when a list or detail response is mapped (decision 8) — plus a separate pure function computing the `position / duration >= 0.9` rule, used only by `VideoPlaybackService` and `MusicPlayerService` in slice 008 when *reporting* watched state to the server. Both live in Domain; only the mapper call site (Data, slice 005) and the reporting call site (Services, slice 008) are deferred.

**Out of scope** (name the slice it's deferred to):
- Any DTO, JSON decoding, or `CodingKeys` — that is `MixtapeData`, starting slice 004.
- `AuthContext` — explicitly placed in `MixtapeInfrastructure` by §4, not Domain (slice 003).
- Repository protocols and use case types — `MixtapeUseCase`, slice 003 onward per the build order, first populated in slice 004.
- Wiring `isAVPlayerNative` or `MediaSourceCandidate` into an actual resolve path — slice 006.
- Wiring the `>= 0.9` reporting rule into a service — slice 008.

**Plan requirements covered:** none. This slice covers no engineering-doc §1/§12 capability directly — it is foundation that every later slice's `covers:` depends on. Recorded in the checklist as foundation, per the plan.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

- [ ] Opened `001-package-skeleton-and-gates.md`. Its decision log still says what this slice assumed: `MixtapeDomain` and `MixtapeDomainTests` exist as targets in `MixtapeKit/Package.swift`, each carrying `swiftSettings: [.defaultIsolation(MainActor.self), .swiftLanguageMode(.v6)]`, and `MixtapeDomainTests` has its placeholder `@Test` still passing.
- [ ] 001 is not a spike, so no fallback question applies — its outcome is either shipped as planned or drifted, checked below.
- [ ] 001's state matches what this slice assumed when drafted: the six-target skeleton exists, `check-layer-imports.sh` exits 0, and nothing under `Sources/MixtapeDomain` yet exists beyond the placeholder the skeleton slice left there.
- [ ] Architecture standards doc (`docs/architecture.md`) re-read; nothing changed underneath this slice — in particular that Domain still depends on nothing but Foundation, and that `SPEC-DECISIONS.md` decisions 1–35 remain the current binding set.

**Drift found:** none.

## 5. Acceptance Criteria

- [ ] `MixtapeDomainTests` builds and every fixture-table case in `isAVPlayerNative` passes: `(mp4, h264, aac)` → `true`; `(mkv, h264, aac)` → `false`; `(mkv, hevc, dts)` → `false`; `(mov, hevc, ac3)` → `true`; `(webm, vp9, opus)` → `false`; `(mp4, h264, dts)` → `false`; `(mp4, av1, aac)` → `false`; `(mp4, h264, nil)` → `true`; `(mkv, h264, nil)` → `false` (decision 39 — the Avatar mp4 has no audio track).
- [ ] A tick round-trip test passes: `Duration.seconds(n).ticks == n * 10_000_000` and `Duration(ticks: n * 10_000_000) == .seconds(n)` for at least one non-zero `n`.
- [ ] The watched-threshold pure function is tested at 89.9%, 90.0% and 90.1% of a fixed duration, asserting `false`, `true`, `true`.
- [ ] `displayTitle` is tested for an episode (`parentIndexNumber: 2, indexNumber: 4, name: "Title"` → `"S2E4 · Title"`), a track (`indexNumber: 3, name: "Title"` → `"3. Title"`), and a movie (`name: "Title"`, no index numbers → `"Title"`).
- [ ] `MixtapeError` has exactly the eight §4 cases plus `.decoding`, and no `.forbidden` case — checked by a test that switches over it exhaustively (a missing or extra case fails to compile, which is the test).
- [ ] `QuickConnectUIState` has exactly `.idle`, `.waiting(code:)`, `.failed(MixtapeError)` — same exhaustive-switch check.
- [ ] `xcodebuild build` is green for both the `iOS` and `tvOS` schemes with `MixtapeDomain` populated.
- [ ] `xcodebuild test -skip-testing:iOSUITests` (iOS scheme) and `-skip-testing:tvOSUITests` (tvOS scheme) are green, including the new `MixtapeDomainTests` cases.
- [ ] `./scripts/check-layer-imports.sh` exits 0 — nothing under `Sources/MixtapeDomain` imports anything but Foundation.
- [ ] `swiftformat --lint .` is clean.

## 6. Decision Log

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-03 | `PlaybackPlan` gains a `playMethod: PlayMethod` field alongside `method: PlaybackMethod`; `PlayMethod` is a new Domain enum (`.directPlay`, `.directStream`, `.transcode`) | Widening `PlaybackMethod` to cover both axes; reporting `.directPlay` for everything non-transcode | Cited from `SPEC-DECISIONS.md` decision 11 — not re-argued here. |
| 2026-09-03 | `QuickConnectUIState` is `.idle`, `.waiting(code:)`, `.failed(MixtapeError)`, and the `SessionService` property that will hold it (slice 004) is non-optional | An optional `QuickConnectUIState?` with `nil` meaning idle | Cited from `SPEC-DECISIONS.md` decisions 24 and 28 — not re-argued here. |
| 2026-09-03 | `PlaybackState.isWatched` is a stored value the mapper sets from `UserData.Played`; the `>= 0.9` ratio is a separate pure function used only when reporting | Computing `isWatched` from a ratio at mapping time, using a `PlayedPercentage` field | Cited from `SPEC-DECISIONS.md` decision 8 — not re-argued here; the server never sends `PlayedPercentage`. |
| 2026-09-03 | `ServerIdentity.id` / `.name` / `.version` stay non-optional in Domain; the Data-layer DTO carries the optionality and the mapper enforces the assertion | Making the Domain fields optional to mirror the wire schema | Cited from `SPEC-DECISIONS.md` decision 31 — not re-argued here; this slice only defines the non-optional Domain shape, the throwing mapper is slice 004's. |
| 2026-09-03 | `MixtapeError` has no `.forbidden` case; unmapped 4xx is a Data-layer concern (`.transport`), not a new Domain case | Adding `.forbidden` for 403 | Cited from `SPEC-DECISIONS.md` decision 9 — not re-argued here. |
| 2026-09-03 | `isAVPlayerNative` treats a `nil` audio codec as native (decision 39, cited not re-argued) | Requiring a member of the audio list, so `nil` fails | The library's only `.directAVPlayer` candidate has no audio stream; under the strict rule it routes to `.directVLC` and AC6 fails against correct code, with no fixture row to catch it |
| 2026-09-03 | A new Domain type, `MediaSourceCandidate`, is introduced ahead of §4 to carry what `resolveVideo` will return once decision 12 lands in slice 006 | Waiting until slice 006 to define it, leaving the repository return type undecided until then | §4 does not name this type because the doc originally had the repository return a finished `PlaybackPlan`; decision 12 moved selection to the use case, which needs an intermediate shape. Defining it now means slice 006 has no Domain work left to do, only wiring. |

## 7. Sub-Slices

Not split — delivered as a single slice.

## 8. Testing Strategy

- **Unit / Integration / UI:** Unit only, all pure functions and value-type invariants — no I/O, no mocks, no `URLProtocol` stub (that starts in slice 003). No XCUITest, no CI (decision 4).
- **Test targets required:** `MixtapeDomainTests`, tagged `.domain`. The target already exists from slice 001 with one placeholder `@Test`; this slice replaces the placeholder with the real suite and does not need to create the target.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`002: add domain model and pure rules`).

Nothing checks any of this. That's the point of putting the writes first — a write you have to do to proceed is one you do; a write you're supposed to do afterwards is one you don't.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and that page's `previous_slice`

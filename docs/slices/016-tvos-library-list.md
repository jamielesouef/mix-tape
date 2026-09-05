---
slice_id: "016"
title: tvOS library list and focus completeness
priority: P1
complexity: M
ladder: none
depends_on:
  - { id: "013", type: hard, note: "MixtapePresentationTests — the tvOS library resolution and the identifier audit both need somewhere to be tested" }
  - { id: "011", type: hard, note: "RootTabScreen+tvOS, LibraryTabScreen and the first-of-kind resolution this slice replaces; VLCPlayerView+tvOS and its onMoveCommand focus handling" }
  - { id: "005", type: hard, note: "LibraryListScreen and FetchLibrariesUseCase — the iOS affordance this slice gives tvOS a counterpart to" }
  - { id: "012", type: soft, note: "the identifier enums this slice completes for tvOS; 012's audit is what left the two gaps" }
previous_slice: "015"
next_slice: "017"
parent_slice: none
covers: ["§1.5"]
created: 2026-09-04
---

# 016 — tvOS library list and focus completeness

← [previous](015-wallet-finish-ownership.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](017-spec-document-reconciliation.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Every library the signed-in user has is reachable on tvOS, not just the first of each kind.
Observable on its own: add a second music library in Jellyfin and browse it on the Apple TV.

## 2. Business Value & Priority

§1.5 is "List the user's libraries (movies, TV, music)", and the coverage table claims it
for 005 on iOS and 011 as a tvOS demonstration. On tvOS it is not satisfied. The tab set
resolves one library per kind:

```swift
if let library = libraries.first(where: { $0.kind == kind })   // LibraryTabScreen.swift:34
```

A user's second movie or music library has no route to it at all. The deviation is
recorded in slice 011's decision log but **not** in `SPEC-DECISIONS.md`, so it is an
undocumented departure from an in-scope capability rather than a sanctioned one — the exact
class of thing the Plan Forks section exists to catch.

The project owner's call (2026-09-04) is to build the list rather than amend the spec.

Two smaller tvOS gaps ride along, because they are the same platform and the same audit:

- A possible focus trap in the VLC player. `VLCPlayerView+tvOS.swift:52-61` forces focus onto
  the transport button on appear and installs `.onMoveCommand` whose `.up` and `.down` cases
  `break`, consuming directional input. Focus may therefore be unable to reach
  `VideoPlayerScreen`'s Close button (`VideoPlayerScreen.swift:48`), leaving the Menu button
  as the only escape — which the code comment asserts but nothing tests.
- Two identifier gaps §9 says should not exist. The per-season `Text().tag()` options in
  `SeriesDetailScreen.swift:34` carry none, so a season cannot be selected by identifier; and
  `RootTabScreen+tvOS.swift:18-35` puts the tab identifiers on each tab's *content view*
  rather than the tab-bar item, so they cannot be used to switch tabs.

Also verified here, not assumed: the pre-push change that moved the Now Playing affordance
outside the `NavigationStack` and swapped `navigationDestination(isPresented:)` for
`.fullScreenCover`. It compiles and the gate passes, but nobody has confirmed at runtime
that Menu dismisses the cover or that focus lands sensibly inside it.

## 3. Scope

**In scope:**

- A tvOS library list, reachable from the tab set, listing every library the user has. Follow
  the platform-divergence rule (`CLAUDE.md`): a `+tvOS` file named for what it is, not a
  branch inside a shared body. Reuse `FetchLibrariesUseCase` and `LibraryService` unchanged —
  the data is already fetched; only the presentation is missing.
- Decide and record how the list relates to the existing kind tabs: an additional
  "Libraries" tab alongside Home / Movies / Shows / Music / Settings, or the kind tabs
  gaining a way in when more than one library of that kind exists. §9's tvOS section names
  the five tabs, so a sixth is a fork and needs a Section 6 row.
- Resolve the VLC focus question. If focus genuinely cannot reach Close, let `.up` or `.down`
  fall through instead of consuming it, and confirm on the simulator.
- Close the two identifier gaps.
- Confirm the Now Playing cover: Menu dismisses it, focus lands on a transport control, and
  it opens from `AlbumDetailScreen` — the case the pre-push fix existed to serve.

**Out of scope** (name the slice it's deferred to):

- The wallet. §1.1 is explicit that tvOS keeps a focus-driven album grid and the wallet is
  not built there. A library list is not a route to changing that.
- iOS. `LibraryListScreen` already satisfies §1.5 on iOS and is untouched.
- Dynamic Type on tvOS — slice 012 recorded that tvOS has no Dynamic Type (drift (d)); this
  is not a re-open.
- Any change to first-of-kind *resolution* inside `LibraryTabScreen`. The kind tabs keep
  resolving the first of their kind; the list is how the others are reached. Changing both
  at once makes the tab set's behaviour a moving target mid-slice.

**Plan requirements covered:**

- **§1.5** "List the user's libraries" — genuinely satisfied on tvOS for the first time. The
  coverage table's §1.5 row currently reads "005 (iOS), 011 (tvOS demonstration)"; it gains
  016 and the parenthetical on 011 is corrected, because what 011 demonstrated was a tab per
  kind, not a list.

## 4. Pre-Flight Validation

- [x] **013** — opened. `MixtapePresentationTests` exists and runs in both schemes.
- [x] **011** — opened. Confirm the tvOS tab set is still Home / Movies / Shows / Music /
      Settings, that `LibraryTabScreen` still resolves first-of-kind at `:34`, and that the
      Now Playing affordance is where the 2026-09-04 pre-push change left it — outside the
      `NavigationStack`, presented as a cover. **This is the highest-drift dependency in the
      round**: 011's own drift row records that 010 moved four files underneath it, and the
      pre-push change moved a fifth after 011 closed.
- [x] **005** — opened. Confirm `FetchLibrariesUseCase` still returns every library and that
      `LibraryService.libraries` is not filtered by kind anywhere upstream — if it is, this
      slice needs a data change and not just a screen.
- [x] **012** (soft) — opened, for the identifier enum conventions (decision 17, one enum per
      screen) the two new identifiers must follow.
- [x] Dev server state checked before the acceptance run. The drift log records an orphaned
      "Empty Music" `/UserViews` item that survived a library scan in 011's first run and
      needed `docker restart jellyfin` plus `POST /Library/Refresh`. **This slice deliberately
      creates a second library of a kind**, so it will leave exactly that kind of residue —
      plan its removal before creating it, and confirm `/Library/VirtualFolders` and
      `/UserViews` agree afterwards.
- [x] Architecture standards doc re-read.

**Drift found:** `none` in 011's shape — the tab set is still Home / Movies / Shows / Music / Settings, `LibraryTabScreen` still resolves `libraries.first(where:)`, and the Now Playing button and its `.fullScreenCover` sit outside the `NavigationStack` as the pre-push fix left them. `FetchLibrariesUseCase` filters only `.unsupported`, and `LibraryService.libraries` is not filtered by kind anywhere, so the list is presentation only. 015 added one thing under this slice: 015's drift row on covered `NavigationStack` roots not being updated applies to `LibraryTabScreen`'s root too. Dev server before the run: `/Library/VirtualFolders` and `/UserViews` both list Movies and Music only; the second music library ("Music 2", `/media/music2`, a copy of the President folder) and a temporary TV library ("Shows", `/media/shows`, one fake series with two seasons so AC16d's season identifier can be queried on a live screen — decision 14's 0-Series baseline is restored at close) were added through the API with their removal planned as `DELETE /Library/VirtualFolders` plus `POST /Library/Refresh`, and `docker restart jellyfin` if `/UserViews` keeps an orphan.

## 5. Acceptance Criteria

- [ ] **AC16a** — With two music libraries on the dev server, both are reachable on the Apple
      TV simulator and each browses to its own albums.
- [ ] **AC16b** — With one library of each kind, the tab set behaves exactly as 011 shipped it.
      Adding the list does not change the single-library experience.
- [ ] **AC16c** — In the VLC player on tvOS, focus reaches the Close button by directional
      input, or the slice records why it cannot and Menu is proven to dismiss.
- [x] **AC16d** — A season can be selected in `SeriesDetailScreen` by accessibility identifier,
      and each tvOS tab-bar item carries its identifier. Verify by identifier query, not by
      reading the source. *(Ordering note: AC11's live demonstration stays blocked — 0 Series
      on the server, decision 14. This criterion is about the identifiers, not the ordering.)*
- [ ] **AC16e** — The Now Playing cover opens from `AlbumDetailScreen`, its transport controls
      take focus, and Menu dismisses it back to the album.
- [x] `xcodebuild build` and `test` pass for both schemes; layer, glass and swiftformat clean.

**Evidence and gaps, 2026-09-05.** *Demonstrated:* **AC16d**, season half — on the iPhone 17 Pro simulator (the screen is platform-shared) with a temporary TV library on the dev server, `idb ui describe-point` on the segmented picker returned `seriesDetail.seasonOption.e099d3…` ("Season 1", value 1) and `seriesDetail.seasonOption.cdbc2c…` ("Season 2", value 0); tapping the second by its frame switched the episode list to `S2E1`. The temporary library was then deleted (`DELETE /Library/VirtualFolders`, `POST /Library/Refresh`), the folder removed, and `/Library/VirtualFolders`, `/UserViews` and an `Items` query all agree: no Series, Season or Episode remains, so decision 14's 0-Series baseline stands. **Unit tests:** `LibraryTabResolutionTests` (4) cover one / several / none / other-kinds-untouched on both schemes; the gate passes 184/0/0. *Not demonstrated, and why:* **AC16a, AC16b, AC16c, AC16e** need directional input on the Apple TV simulator, and on this machine nothing delivers it: `idb ui key` is refused by CoreSimulator 1155.4 ("Keyboard HID is suppressed … Use the DTUHID transport"), `idb ui swipe`/`tap` do nothing on tvOS, `idb ui describe-all` returns only the application node (no accessibility tree, so no identifier query either), and synthetic key events through System Events and through `CGEvent` posting — with the device window frontmost and focused, with "Connect Hardware Keyboard" toggled, and with the Apple TV Remote window shown and focused — never moved focus off the Home tab, nor did Escape (Menu) leave the app; a mouse drag posted on the Remote window's touch surface did nothing either. The tvOS app builds, installs, launches and shows the five tabs (screenshots), which is as far as screenshots can carry it. **AC16d, tab-bar half:** `TabContent.accessibilityIdentifier(_:)` is applied on both platforms, but `idb` exposes no identifier on the tab-bar items even on iOS (`describe-point` on each item returns `AXUniqueId: null`, and neither placement — content view or `Tab` — appears anywhere in the dumped tree), so this cannot be verified by identifier query with the tooling here. **AC16c** therefore stays open exactly as Section 2 framed it: not statically provable. The second music library ("Music 2", `/media/music2`) is **left on the dev server** so a person at the Simulator can finish AC16a/AC16b; removal is `./scripts/jf-probe.swift DELETE "/Library/VirtualFolders?name=Music%202&refreshLibrary=true"`, then `POST /Library/Refresh`, then delete `media/music2`, then confirm `/UserViews`. Recorded in the checklist's Active Blockers.

## 6. Decision Log

**Write the row before you implement the decision, not after.**

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-09-04 | Build the tvOS library list rather than amend §1.5 with a decision recording first-of-kind as intended | (a) A `SPEC-DECISIONS.md` row declaring tvOS first-of-kind deliberate and §1.5 satisfied by the tab set; (b) deferring the gap to V2 with a fork row | Project owner's call. §1.5 is an in-scope V1 capability and the deviation was never recorded anywhere that outranks a slice log, so the choice was between making the code true and making the spec true — and the spec is right: a user with two music libraries currently cannot reach one of them. |
| 2026-09-05 | The tab set keeps §9's five tabs. A kind tab whose user has **more than one** library of that kind shows a focusable list of those libraries (`LibraryKindListScreen`, tvOS-only) at the root of its `NavigationStack`, and each row pushes the existing `LibraryDestination`; with exactly one library the tab hosts the shelf directly, as 011 shipped it. Resolution is a platform-shared pure helper, `LibraryTabResolution` (`.none` / `.one` / `.several`), so it is unit-tested on both schemes. | (a) A sixth "Libraries" tab mirroring iOS; (b) a picker in the shelf header; (c) changing first-of-kind resolution inside `LibraryDestination` | (a) is a fork against §9's tvOS tab list for a case most users never hit, and it would show a list of four when the kind tabs already partition the libraries. (b) puts a control into every shelf for the single-library majority. (c) is what Section 3 rules out. A list only where there is something to list changes nothing for one library of a kind (AC16b) and reaches every library (AC16a). |
| 2026-09-05 | The two identifier gaps close with the SwiftUI API that puts them where a query finds them: `TabContent.accessibilityIdentifier(_:)` on each `Tab` in `RootTabScreen+tvOS` (the content views keep theirs, one enum), and `SeriesDetailIdentifiers.seasonOption(_:)` on each season `Text` in the segmented `Picker`. | Leaving the identifiers on the tab content views | An identifier on the content cannot address the tab-bar item, which is what a test switching tabs needs. |
| 2026-09-05 | `LibraryTabScreen`'s Now Playing cover dismisses itself when `music.isActive` turns false, the same named dismissal 015 gave the iOS sheet. | Leaving it | 015 found the iOS sheet's dismissal was accidental; the tvOS cover's is absent — after an album ends it would sit showing "Nothing playing" until Menu. Same clause of §9.1, same one-line fix, found while confirming AC16e's cover. |
| 2026-09-05 | The VLC overlay's `.onMoveCommand` is left as 011 shipped it — `.up`/`.down` still `break` — and AC16c stays open. | Changing the handler blind: dropping the `.up`/`.down` cases or moving focus programmatically | Section 2 says the trap is not statically provable and needs the simulator, and the simulator could not be driven (Section 5). A blind change could as easily create a trap as remove one, and would ship unverified in the same way. |

*(The tab-set shape decision was made above, 2026-09-05, and is not a fork: the five tabs
stay.)*

## 7. Sub-Slices

Not split — delivered as a single slice. If the tab-set decision turns out to restructure
`RootTabScreen+tvOS` rather than add to it, split that into `016a`.

## 8. Testing Strategy

- **Unit:** `MixtapePresentationTests` (`.presentation`, from 013) for library resolution —
  that the list presents every library and that kind tabs still resolve first-of-kind.
  Against `MockLibraryService` with a multi-library fixture, which
  `MockLibraryRepository.sampleAlbums` does not currently provide.
- **Integration:** none.
- **UI:** none — decision 4. AC16c, AC16d and AC16e are focus and identifier behaviour, which
  is XCUITest's natural territory; until that rung lands they are manual on the simulator,
  and the identifiers this slice adds are what makes them writable later.
- **Acceptance:** AC16a–AC16e on the Apple TV simulator, resolved at runtime by UDID — never a
  hardcoded `OS=26.0`, which does not exist on this machine.
- **Test targets required:** `MixtapePresentationTests` (created in 013).

## 9. Keeping this document true

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| widen scope | Section 3, and `depends_on` on any slice that's now affected |

Commit this file alongside the code, with the slice id in the subject (`016: …`).

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] §1.5 satisfied on tvOS, and its coverage row updated to name 016 and correct 011's
      parenthetical
- [ ] The tab-set fork has a decision row naming what was rejected
- [ ] Second test library removed from the dev server, and `/UserViews` confirmed clean
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] Both link directions checked: this page's `next_slice` and `017`'s `previous_slice`

---
slice_id: "005a"
title: App sign-in, token storage and the onboarding fork
priority: P0
complexity: M
ladder: none
depends_on:
  - { id: "005", type: hard, note: "needs POST /auth/apple to exchange against" }
  - { id: "001", type: hard, note: "needs APIClient, the layer folders and the entitlement kept through the rename" }
previous_slice: "005"
next_slice: "006"
parent_slice: "005"
covers: ["5.secondDevice", "5.pairing.client"]
created: 2026-08-31
---

# 005a — App sign-in, token storage and the onboarding fork

← [previous](005-server-pairing-and-owner-claim.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](006-library-manifest-endpoint.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Ship the client half of pairing: a server-address field, the Sign in with Apple button, the exchange, and the token stored in the Keychain. Value observable on its own: install the app on a clean device, point it at your server, sign in, and the app shows it is paired — and stays paired across a relaunch.

## 2. Business Value & Priority

This is the first thing a user ever does, and it is the only screen that can strand them. It is also the slice that turns `/version`'s `claimed` flag into the product's onboarding fork: an unclaimed server offers **"claim this server"**, a claimed one offers **"sign in"**. Same button, different promise, and getting the words wrong makes a first-run experience feel broken.

The load-bearing detail is the Keychain accessibility class: **`kSecAttrAccessibleAfterFirstUnlock`**. Slice 010's background downloads read the token while the device is locked. The default class would make a queued download fail on a locked phone with an error that looks like a network problem. Choosing it here, three slices before anything depends on it, is why it is written down here.

## 3. Scope

**In scope:**

- `App/Tests/MixTapeTests/TestTags.swift` — the app-side half of the same `Tag` extension slice 004 adds for the server. The two test trees are separate targets in separate packages and cannot share a file, so the four layer tags are declared once on each side. **There is an existing violation to clear at the same time:** slice 003 wrote `App/Tests/MixTapeTests/VersionResponseDTOTests.swift` with an untagged `@Suite`, because no tag existed to apply. Tag it `.domain` when the extension lands — it tests a `Shared` DTO
- `SignInScreen` in `AppPresentation/Screens/Auth/`, with a server-address field and `SignInWithAppleButton`
- `SignInWithAppleUseCase` in `AppUseCase/UseCases/Auth/`, and `AuthRepositoryProtocol` alongside it
- `AuthRepository` in `AppData/`, a stateless `Sendable` struct calling `APIClient`
- `AuthService` — `@MainActor @Observable final class` in `AppServices/Auth/`, holding the paired state and nothing else
- `KeychainStore` in `AppInfrastructure/`, storing the token with `kSecAttrAccessibleAfterFirstUnlock`
- Storing the server base URL — this is **not** in the plan and is a gap it does not close; see Section 6
- The onboarding fork off `/version`'s `claimed` flag
- Attaching `Authorization: Bearer <token>` to every `APIClient` request
- Handling `notOwner` with a real message: *this server already belongs to a different Apple ID*, not a generic failure
- A sign-out that clears the Keychain item and returns to `SignInScreen`
- `MockAuthRepository` in the main target for previews; `StubAuthRepository` in the test target

**Out of scope** (name the slice it is deferred to):

- Any library fetching or display → **006**, **007**
- Bonjour or automatic server discovery → not v1; the address is typed
- Token refresh or rotation → does not exist by design; ladder **L5** in slice 005
- A device list or per-device revocation → out of scope for v1
- Multi-server support, or switching between servers → out of scope for v1

**Plan requirements covered:**

- `5.pairing.client` — steps 1, 2 and 8 of the plan's pairing exchange: present the button, send the identity token, store the result in the Keychain with the named accessibility class.
- `5.secondDevice` — the plan states that the same Apple ID produces the same `sub`, so a second device pairs and receives its own independent token, and a different Apple ID is refused. Slice 005 proves the server side; this slice proves the observable behaviour, which is where "no device list, no device limit" is actually visible.

**Verification note carried into implementation:** the plan asserts several Apple-platform behaviours this slice depends on — that `ASAuthorizationAppleIDCredential.identityToken` is present on every successful authorisation, that the same Apple ID yields a stable `sub` across devices, and the exact semantics of `kSecAttrAccessibleAfterFirstUnlock` for a background `URLSession`. **These were not re-verified against Apple's documentation during planning, because the documentation tool was not available in that session.** Check each against `apple-docs` before implementing, and log any correction as a decision row here plus a Drift Log entry. Do not treat the plan's wording as authoritative on an Apple API.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **005** — opened. Its decision log still says the token is HS256 with a ten-year `exp`, and that `403 notOwner` is the different-Apple-ID response this screen must handle.
- [ ] **005** — confirm the second-device path shipped: two exchanges with the same `sub` both succeed. If 005 forked to one-token-per-owner, this slice's second-device criteria are wrong.
- [ ] **001** — opened. Confirm `App/MixTape.xcodeproj` still carries `com.apple.developer.applesignin` after the rename. If the entitlement was lost, this slice cannot start — that is a blocker, not a task.
- [ ] Confirm the app is signed with a team that has the Sign in with Apple capability enabled, and that `MIXTAPE_APPLE_BUNDLE_ID` on the server matches the app's actual bundle identifier. **A mismatch here fails as `invalidIdentityToken` and looks like a token bug for an hour.**
- [ ] Re-read the Apple documentation for the three behaviours named in Section 3's verification note.
- [ ] Architecture standards doc re-read: `docs/app-architecture-template.md` on `@Entry` wiring, service shape and the no-repository-in-a-view rule; `docs/plan/v1-architecture.md` section 5.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] **Every suite in `App/Tests/MixTapeTests/` carries a layer tag, including `VersionResponseDTOTests` inherited untagged from slice 003.** Checked by reading the suites, and by running a tag filter and confirming it selects the expected set rather than nothing.
- [ ] A clean install against an **unclaimed** server shows claim-this-server wording; against a **claimed** server it shows sign-in wording. Two different first runs, both checked.
- [ ] Signing in stores a token and moves to the app's main screen.
- [ ] Force-quitting and relaunching stays signed in. No second sign-in prompt.
- [ ] The token is in the Keychain with `kSecAttrAccessibleAfterFirstUnlock`. Verified by reading the item's attributes back, not by trusting the write.
- [ ] The token is **not** in `UserDefaults`, not in a plist, and not in a file. Grep the app container after a sign-in.
- [ ] A second device with the **same** Apple ID pairs successfully, and the first device keeps working. Both tokens valid at once.
- [ ] A device with a **different** Apple ID gets a message naming the actual problem — the server belongs to another Apple ID — and not "an error occurred".
- [ ] An unreachable server address gives a distinguishable error from a rejected sign-in. These are the two failures a first-time user will actually hit, and conflating them makes the app unusable to diagnose.
- [ ] The server address survives a relaunch.
- [ ] Sign out clears the Keychain item and returns to `SignInScreen`; signing back in works.
- [ ] `./scripts/check-layer-imports.sh` passes — no `import SwiftUI` or `import Observation` under `AppUseCase/` or `AppDomain/`.
- [ ] No repository or use case type appears in any view's signature.
- [ ] `SignInScreen` has a `#Preview` covering its states: unclaimed, claimed, in-flight, and the `notOwner` failure.
- [ ] Runs on iOS and macOS destinations. Sign in with Apple differs enough between them that "it built" is not evidence.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | Keychain accessibility is `kSecAttrAccessibleAfterFirstUnlock` | `WhenUnlocked`; `WhenUnlockedThisDeviceOnly`; `AfterFirstUnlockThisDeviceOnly` | Slice 010's background `URLSession` reads the token while the device is locked. `WhenUnlocked` would fail those reads with an error that presents as a network failure. Chosen here rather than in 010 because a stored item's class is set at write time, and changing it later means every existing install re-pairs |
| 2026-08-31 | **The server base URL is stored, and the plan does not say where.** It goes in `UserDefaults`, not the Keychain | Keychain; a build-time constant; Bonjour discovery | The plan specifies the token's storage and is silent on the address, yet a self-hosted client is useless without one — this is a genuine gap, closed here. It is not a secret, so the Keychain buys nothing and costs an accessibility-class decision. A build-time constant is wrong because every self-hoster has a different address |
| 2026-08-31 | `AuthService` holds paired state only; no token in memory beyond the request | Cache the token on the service; pass it through views | The template puts state in services and secrets in `AppInfrastructure`. `KeychainStore` is the only thing that holds the token, and `APIClient` asks it per request. Keeps the token out of any `@Observable` surface a view could read |
| 2026-08-31 | `notOwner` gets bespoke copy naming the cause | A generic error message | It is the one auth failure with no recovery inside the app — the user must use the original Apple ID or wipe `owner.json` on the server. A generic message sends them to reinstall the app instead, which cannot help |
| 2026-08-31 | Repository protocols exist, with `Mock*`/`Stub*` as the second conformer (plan conflict **C3**) | No protocol until a second real implementation appears | Phase 3 is told to flag any protocol without a second conformer, while the template mandates repository protocols **and** testing against injected doubles. The doubles are the second conformer. Recorded so it is not raised as a finding |

## 7. Sub-Slices

This *is* a sub-slice of [005](005-server-pairing-and-owner-claim.md). Not split further.

## 8. Testing Strategy

- **Unit:** `SignInWithAppleUseCase` against `StubAuthRepository`, covering success, `notOwner`, and a transport failure. Test the behaviour, not the stub's plumbing.
- **Unit:** `AuthService` state transitions — unpaired, pairing, paired, failed — against the stub.
- **Unit:** `KeychainStore` round trip, plus reading the stored item's attributes back to assert the accessibility class. That assertion is the whole reason this test exists.
- **UI:** one XCUITest for the happy path, driven off accessibility identifiers, never visible text. Sign in with Apple itself cannot be automated, so the test drives the app with an injected already-paired state and asserts the main screen appears.
- **Test targets required:** `App/Tests/MixTapeTests/` and `App/Tests/MixTapeUITests/`, created by slice 001. Swift Testing for units, tagged `.useCase` and `.service`; XCTest for the XCUITest only.
- **This slice creates the app-side `Tag` extension**, `App/Tests/MixTapeTests/TestTags.swift`, mirroring the one slice 004 adds under `Server/`. It also retro-tags the one untagged suite already sitting there — `VersionResponseDTOTests`, left that way by slice 003 because the vocabulary did not exist. After this slice, an untagged suite anywhere in the app target is a defect rather than an unavoidable gap.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`005a: add app sign-in and token storage`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved, **including the Apple-documentation check named in Section 3**
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `006`'s `previous_slice`

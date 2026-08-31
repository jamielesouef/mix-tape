---
slice_id: "005"
title: Server pairing, the owner claim and the bearer middleware
priority: P0
complexity: L
ladder: "token revocation v1 of 2 — v2 is a jti denylist, shared seam: the jti claim already minted into every token plus the TokenVerifier type"
depends_on:
  - { id: "004a", type: hard, note: "delivery order only; this slice needs nothing from the scan" }
  - { id: "001", type: hard, note: "needs ServerConfiguration, MixTapeJSON, ErrorResponseDTO and the /version claimed flag" }
previous_slice: "004a"
next_slice: "005a"
parent_slice: none
covers: ["1.AuthExchange", "1.ErrorResponseDTO", "3.authApple", "5.pairing", "5.secret", "5.middleware", "5.config"]
created: 2026-08-31
---

# 005 — Server pairing, the owner claim and the bearer middleware

← [previous](004a-album-artwork-extraction.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](005a-app-sign-in-and-token-storage.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Implement `POST /auth/apple` end to end on the server: verify an Apple identity token, claim the server on first use, issue a long-lived HS256 token, and add the bearer middleware every other authenticated route will sit behind. Value observable on its own: `curl` an identity token at the server and get a working token back; `curl` a protected test route without one and get `401`.

## 2. Business Value & Priority

**This slice sits before every authenticated endpoint on purpose.** `GET /library`, `POST /library/rescan`, `/artwork` and `/audio` are all bearer-authed. If they shipped first, none of them could carry a "rejected without a token" acceptance criterion, and slice 005 would be retrofitting middleware under routes that already worked without it. Auth added after the fact is auth with holes in it.

The design's core move is that **Sign in with Apple is used once, for pairing — it is not the session mechanism.** Apple's identity token is short-lived, and refreshing it needs server-to-server calls with a client-secret JWT that Apple caps at six months. That is an indefinite rotation chore on a box in a cupboard, and it is the single most likely thing to break a self-hosted server two years from now while its owner is not watching. Issuing our own token removes that entirely.

The ten-year expiry is not laziness either — it is what makes slice 010's background downloads work. A download queued days ago and resumed after a relaunch must still authenticate without a live user.

**Ladder L5 — token revocation (this slice ships the crude rung).** v1's whole revoke story is: delete or rotate `<dataDir>/secret`, which invalidates every issued token at once. The seam is the `jti` claim, which is minted into every token from day one even though nothing reads it, plus the single `TokenVerifier` type that every route's check goes through. v2 adds a `jti` denylist inside that one type. Minting an unused claim now costs a line; adding it later means every already-issued ten-year token lacks it.

## 3. Scope

**In scope:**

- `AuthExchangeRequestDTO` and `AuthExchangeResponseDTO` added to `Shared`
- `POST /auth/apple`, unauthenticated
- Fetching Apple's public keys from `https://appleid.apple.com/auth/keys`, cached in memory, refreshed when an unknown `kid` appears
- Verification with JWTKit: signature, `iss == "https://appleid.apple.com"`, `aud == MIXTAPE_APPLE_BUNDLE_ID`, `exp` not passed
- The ownership check against `<dataDir>/owner.json`: absent → write `{ "sub": …, "claimedAt": … }` and claim the server; present and matching → proceed; present and differing → `403` with `APIErrorCode.notOwner`
- Issuing the server's own token: HS256, claims `{ sub, iat, jti }`, `exp` ten years out
- The server secret: `MIXTAPE_TOKEN_SECRET` if set, otherwise generated on first boot and written to `<dataDir>/secret` with mode `0600`
- `TokenVerifier` and the bearer middleware — verifies the HS256 signature, then checks `sub` still equals the owner's `sub`. Two cheap checks, no I/O per request
- Making `/version`'s `claimed` flag meaningful, by reading whether `owner.json` exists
- One protected test route, so the middleware has something to guard before slice 006 exists

**Out of scope** (name the slice it is deferred to):

- `SignInWithAppleButton`, `AuthService`, `KeychainStore`, the sign-in screen → **005a**
- Applying the middleware to `/library` and `/library/rescan` → **006**
- Applying it to `/artwork` → **008**, and `/audio` → **009**
- A device list, a device limit, or revoking one device → out of scope for v1. Ladder **L5** v2 is the nearest thing
- Sharing a library with a second person → out of scope, per the plan
- Rate limiting or brute-force protection on `/auth/apple` → not v1; the endpoint requires a valid Apple-signed JWT, so there is nothing to guess

**Plan requirements covered:**

- `1.AuthExchange`, `1.ErrorResponseDTO` — as specified. `ErrorResponseDTO` and `APIErrorCode` were added in slice 001; this is the first slice that returns one.
- `3.authApple` — `POST /auth/apple`, no auth, returning `AuthExchangeResponseDTO` or `403` `notOwner`.
- `5.pairing`, `5.secret`, `5.middleware`, `5.config` — as specified, server side.
- `5.secondDevice` is **not** covered here and is not uncovered: the server behaviour is identical for a second device by construction, and the *observable* second-device behaviour is verified in **005a** where there is a client to observe it with.
- `5.config` includes plan conflict **C6** — `MIXTAPE_APPLE_TEAM_ID` is documented in compose by slice 003 and read by nothing. Recorded, not reopened.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **004a** — opened. This is a delivery-order dependency only; nothing here reads the manifest. If 004a slipped, this slice can still proceed — but say so in the checklist rather than silently reordering.
- [ ] **001** — opened. Its decision log still says `ServerConfiguration` centralises `MIXTAPE_APPLE_BUNDLE_ID`, `MIXTAPE_TOKEN_SECRET` and `MIXTAPE_DATA_DIR`, and that `/version` exists with a `claimed` field to make meaningful.
- [ ] Confirm ladder **L1**'s outcome: `MIXTAPE_DATA_DIR` is where `owner.json` and `secret` go, and it is **not** `MIXTAPE_CACHE_DIR`. Writing the server claim into a directory a user is told they can wipe is the failure that ladder exists to prevent — check it here, because this is the first slice that writes to `dataDir`.
- [ ] Confirm JWTKit is already a declared dependency of `Server` from slice 001, and that swift-crypto came in transitively as slice 004 assumed.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` section 5.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] `POST /auth/apple` with a valid identity token on a **fresh** server writes `owner.json` and returns a token. The server is now claimed.
- [ ] `GET /version` reports `claimed == false` before that call and `claimed == true` after it.
- [ ] A **second** call with the same `sub` succeeds and returns a **different** token — a different `jti`, both valid. This is the second-device path.
- [ ] A call with a **different** `sub` returns `403` and a body decoding to `ErrorResponseDTO` with `code == .notOwner`.
- [ ] A token with a valid signature but the wrong `aud` is rejected with `invalidIdentityToken`. **Test this explicitly** — an `aud` check that is never exercised is an `aud` check that might not be wired up, and it is the check that stops anyone else's Apple app from claiming the server.
- [ ] An expired identity token is rejected with `invalidIdentityToken`.
- [ ] A token signed with the right shape but the wrong key is rejected.
- [ ] The protected test route returns `401` with `APIErrorCode.unauthorized` for: no header, a malformed header, a token signed with a different secret, and a well-formed token whose `sub` is not the owner's.
- [ ] `<dataDir>/secret` is created on first boot with mode `0600`. Checked with `stat`, not assumed.
- [ ] Deleting `<dataDir>/secret` and restarting makes every previously issued token fail with `401`. **This is ladder L5's entire v1 revoke story and it is proven here or it does not exist.**
- [ ] Setting `MIXTAPE_TOKEN_SECRET` overrides the file, and tokens survive a restart.
- [ ] Every issued token carries a `jti`, and two tokens issued in the same second have different ones. Nothing reads it yet; that is the point.
- [ ] The issued token's `exp` is approximately ten years out.
- [ ] The bearer middleware performs **no** filesystem read per request. Verified by holding the owner `sub` and the secret in memory after boot.
- [ ] An unknown `kid` from Apple triggers exactly one key refresh, not one per request. A misconfigured cache here becomes a request to Apple on every single API call.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | Apple's identity token is used once for pairing; the server issues its own HS256 token | Use Apple's token as the session token; OAuth refresh flow; username and password | Apple's token is short-lived, and refreshing it needs server-to-server calls with a client secret Apple caps at six months — an indefinite rotation chore on a NAS. Our own token also survives ten years, which is what makes slice 010's background downloads authenticate after a relaunch |
| 2026-08-31 | Signed token, no token database | Store issued tokens in a database; opaque tokens with a lookup | A signed token means no per-request storage read and no schema. The cost is that individual revocation is impossible, which ladder **L5** accepts explicitly |
| 2026-08-31 | v1 revocation is rotating `<dataDir>/secret` (ladder **L5**) | A `jti` denylist now; short-lived tokens with refresh; a device table | The seam is the `jti` claim, minted from day one but read by nothing, plus the single `TokenVerifier` type. Adding `jti` later would leave every already-issued ten-year token without one, so it must be minted now even though it costs a line for no present benefit. That asymmetry is exactly what makes this a valid ladder rather than debt |
| 2026-08-31 | `MIXTAPE_APPLE_TEAM_ID` is not read (plan conflict **C6**) | Require it; use it to generate a client secret | Verifying an identity token needs only the bundle ID, as the `aud` claim. Team ID is for generating a client secret, which this design deliberately avoids. Slice 003 documents it in compose with a comment. Recorded so Phase 3 does not raise it |
| 2026-08-31 | One protected test route ships in this slice | Wait for slice 006 to have something real to protect | Middleware with no route behind it is untested middleware. The test route is deleted when slice 006 lands, and that deletion is in 006's scope |
| 2026-08-31 | `owner.json` and `secret` live in `MIXTAPE_DATA_DIR`, never `MIXTAPE_CACHE_DIR` | One directory for both | Ladder **L1**'s whole future value is a user being able to wipe the cache without losing the server claim. Putting the claim in the cache directory destroys that before v2 can exist |

## 7. Sub-Slices

Split once: **[005a](005a-app-sign-in-and-token-storage.md)** covers the client half — the Sign in with Apple button, `AuthService`, `KeychainStore` and the sign-in screen. The split is real because this slice is fully exercisable with `curl` and a test identity token, and the client half has its own distinct risk (Keychain accessibility class, and the entitlement).

## 8. Testing Strategy

- **Unit:** the ownership state machine — absent, matching, differing — as pure logic over a `sub` and an optional stored owner. No JWT, no filesystem. Three cases, and the `403` one is the one that matters.
- **Unit:** token issue-then-verify round trip, including the negative cases: wrong secret, expired, tampered payload.
- **Integration:** `POST /auth/apple` against a **locally generated** key pair standing in for Apple's, with the JWKS endpoint stubbed. Do not call `appleid.apple.com` from a test — a test suite that fails when the network is down is a test suite people learn to ignore.
- **Integration:** the middleware, against the protected test route, covering all four rejection cases in the acceptance criteria.
- **Test targets required:** `Server/Tests/ServerTests/`, created by slice 001. Swift Testing, tagged `.useCase` for the state machine and `.repository` for the routes.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`005: add pairing and bearer middleware`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `005a`'s `previous_slice`

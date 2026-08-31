---
slice_id: "003"
title: Docker image, compose quickstart and CI pipelines
priority: P0
complexity: M
ladder: "image architecture v1 of 2 — v2 is a multi-arch matrix, shared seam: the platforms input of the buildx step in server.yml"
depends_on:
  - { id: "002", type: hard, note: "the compose quickstart completes README.md, and CI runs check-spdx.sh" }
  - { id: "S001", type: soft, note: "an unfavourable answer changes the volume layout in docker-compose.yml" }
previous_slice: "002"
next_slice: "004"
parent_slice: none
covers: ["7.build", "1.linux"]
created: 2026-08-31
---

# 003 — Docker image, compose quickstart and CI pipelines

← [previous](002-licence-split-and-contribution-docs.md) · [Master Checklist](MASTER-CHECKLIST.md) · [next](004-library-scan-to-manifest.md) →

> **Status, owner and blockers live in the master checklist, not here.** Dependencies live in this page's front matter and nowhere else. Each fact has one home; if you find yourself writing it twice, one of the two copies is going to be wrong in a fortnight.

## 1. Objective

Package the server as a Docker image and prove it on Linux in CI. Value observable on its own: a stranger runs `docker compose up`, hits `/version`, and it answers — and from this slice onward, any Apple-only API that leaks into `Shared` fails a build instead of being discovered on the NAS.

## 2. Business Value & Priority

This slice sits third for one reason: **it is the binding proof for `1.linux`.** The plan's own words are that Linux-cleanliness is *"confirmed by inspection at plan time; the binding proof is Phase 2's `server.yml` CI job"*. Until that job exists, every slice that adds a type to `Shared` — 004, 005, and every later one — is guessing. Landing it before the first big `Shared` addition means the failure is caught on the commit that caused it, not three slices later when it is buried.

The Docker layer ordering matters more than it looks: dependencies are resolved **before** sources are copied, so editing a Swift file does not re-fetch Hummingbird. Get that ordering wrong and every server build costs minutes for the life of the project. It is one line's position in a file and it is worth an acceptance criterion of its own.

**Ladder L2 — image architecture (this slice ships the crude rung).** v1 builds a **single** architecture matching the target NAS. The handoff's reasoning holds: cross-building Swift under QEMU on a CI runner takes 20+ minutes. The seam is the `platforms:` input on the buildx step in `server.yml`; v2 adds a second value to that one input and changes nothing else. Named seam, so this is a ladder and not debt.

## 3. Scope

**In scope:**

- Multi-stage `Dockerfile`, build context at the repository root, build stage `swift:6.2-noble` (**not** the handoff's `swift:6.1-noble` — plan conflict **C5**, resolved by the owner)
- Layer order: copy `Shared`, copy `Server/Package.swift` and `Package.resolved`, `swift package resolve`, **then** copy `Server` sources, then `swift build -c release --static-swift-stdlib`
- Runtime stage `ubuntu:noble` with `ffmpeg` and `ca-certificates` and nothing else
- `docker-compose.yml` with the music directory bind-mounted read-only, one data/cache mount, and `MIXTAPE_MUSIC_DIR`, `MIXTAPE_DATA_DIR`, `MIXTAPE_CACHE_DIR`, `MIXTAPE_APPLE_BUNDLE_ID` and `MIXTAPE_TOKEN_SECRET` declared
- `MIXTAPE_APPLE_TEAM_ID` documented in `docker-compose.yml` **with a comment saying it is read by nothing in v1** — plan conflict **C6**
- `.github/workflows/server.yml` — path filters `Server/**` and `Shared/**`; `swift test`, `check-spdx.sh`, `check-layer-imports.sh`, then buildx and push to GHCR
- `.github/workflows/app.yml` — path filters `App/**` and `Shared/**`; `xcodebuild test` on a macOS runner against an iOS simulator destination, plus `check-spdx.sh` and `check-layer-imports.sh`
- Completing `README.md`'s quickstart with the real, working compose invocation
- `.dockerignore` excluding `.build/`, `DerivedData/`, `App/`, `docs/` — the app tree is a large context that the server image never needs

**Out of scope** (name the slice it is deferred to):

- Multi-architecture images → ladder **L2** v2, not v1
- Signed images, SBOM, provenance attestation → not v1
- A release-tagging workflow → not v1; images are pushed on merge to the default branch
- Deploying to the NAS → out of scope entirely; this ships an image, not a deployment

**Plan requirements covered:**

- `7.build` — Dockerfile, layer caching, `--static-swift-stdlib`, single architecture, compose with a music bind mount, both CI workflows with path filters, and `swift run Server` preserved as the dev loop. The last of those is **S002**'s question and is not re-verified here.
- `1.linux` — this is where the claim becomes binding. `server.yml` compiles `Shared` on Linux on every change to it. The interim grep from slice 001 stays, but this is the real check.

## 4. Pre-Flight Validation

Complete **before the first line of code**, not at close.

For **each id in `depends_on`**, in order — do not summarise, walk the list:

- [ ] **002** — opened. Its decision log still says `scripts/check-spdx.sh` exists and exits non-zero on a violation. Both CI workflows call it; if 002 forked and dropped the script, remove those steps rather than shipping a workflow that fails on a missing file.
- [ ] **S001** — spike. Check whether it is answered, and build on **the answer, not the hoped-for answer**. Note explicitly whether the fallback was taken.
  - Favourable: music and cache are independent roots. `docker-compose.yml` mounts them separately and ladder **L1**'s seam is intact.
  - **Fallback taken:** music must be bind-mounted at `<cacheDir>/music`. The compose file changes shape, the README quickstart changes with it, and ladder **L1**'s seam is recorded as weakened in Section 6.
  - If S001 is still unanswered, this slice may proceed with the *independent* layout, but it must then be re-checked when S001 lands. Log that as a soft blocker rather than assuming.
- [ ] Its state matches what this slice assumed when drafted, not when it was written.
- [ ] **Pin the build-stage image, and record the choice as a decision row.** The local toolchain has moved to Swift 6.4 / Xcode 27, ahead of the `swift:6.2-noble` this slice was drafted against — Drift Log, 2026-08-31. **C5**'s principle is what binds: one language level covers the whole repository, because `Shared/` compiles under both sides. So check, in this order, and it is a two-minute check rather than a question for anyone: (1) does a `swift:6.4-noble` image tag exist on Docker Hub? If yes, bump the build stage to it and drop the interim 6.2-features constraint that slices 001 and `CLAUDE.md` carry. (2) If not, keep `swift:6.2-noble` and state in the decision row that `Shared/` and `Server/` are held to Swift 6.2 features, so a 6.4-only construct cannot pass on the Mac and fail in CI. Either way the interim constraint stops being interim, and `CLAUDE.md`'s Swift rules bullet plus slice 001's pre-flight line are updated to match. **(3) Pin the Xcode version in `app.yml` too**, with the same reasoning applied to the other side: `App/` builds on a hosted macOS runner whose Xcode nothing currently pins, so a feature from the local Xcode 27 passes on the Mac and fails CI — the same failure shape as the Docker gap, on the half of the repository the container never sees. Either pin a runner image that carries the local Xcode, or record the version `App/` is held to.
- [ ] Architecture standards doc re-read: `docs/plan/v1-architecture.md` section 7, Build.

**Drift found:** `none` — or what changed, plus a row in the checklist's Drift Log.

## 5. Acceptance Criteria

- [ ] `docker build .` at the repository root produces an image.
- [ ] `docker run --rm -p 8080:8080 mixtape` starts, and `curl localhost:8080/version` returns `200`.
- [ ] **Layer caching is proven, not assumed:** build once, touch a file under `Server/Sources/`, build again — the second build does **not** re-run `swift package resolve`. Record the two build times in the commit message.
- [ ] The runtime image contains no Swift runtime. `docker run --rm --entrypoint sh mixtape -c 'ls /usr/lib/swift'` fails.
- [ ] `docker compose up` with a real music directory bind-mounted read-only starts and answers `/version`.
- [ ] The Dockerfile's build stage is the tag pinned by this slice's pre-flight — `swift:6.2-noble`, or `swift:6.4-noble` if that tag exists and the pre-flight bumped it. Grep for `6.1` in the Dockerfile returns nothing, and the pinned tag has a decision row.
- [ ] `server.yml` triggers on a change to `Shared/**`, and `app.yml` does too. A commit touching only `App/**` triggers `app.yml` and **not** `server.yml`. Verified on a real branch, not by reading the YAML.
- [ ] `server.yml` compiles `Shared` on Linux. Deliberately adding `import CoreGraphics` to a `Shared` file fails that job. **Test the failure case.**
- [ ] **`app.yml` pins an explicit Xcode version**, and that version is recorded in the decision row alongside the Docker tag. An unpinned runner is the app-side twin of an unpinned build image: whatever the runner defaults to becomes the language level `App/` is really held to, silently, and it changes under you when GitHub rotates the image.
- [ ] `README.md`'s quickstart, followed literally by someone who has not read this document, results in a running server.
- [ ] `docker-compose.yml` declares `MIXTAPE_APPLE_TEAM_ID` with a comment stating it is unused in v1.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | Build stage is `swift:6.2-noble` (plan conflict **C5**) | `swift:6.1-noble`, copied from the handoff | `Shared` compiles under both server and app; the lower language level would win and pin the whole repository. **Resolved by the project owner.** The handoff's Dockerfile must not be copied verbatim |
| 2026-08-31 | Single architecture in v1 (ladder **L2**) | Multi-arch buildx matrix from day one | Cross-building Swift under QEMU costs 20+ minutes per CI run for a benefit exactly one person needs today. The seam is the `platforms:` input on the buildx step — v2 is one changed value |
| 2026-08-31 | `MIXTAPE_APPLE_TEAM_ID` is documented in compose but read by nothing (plan conflict **C6**) | Omit it entirely; wire it up for future use | The handoff requires Team ID to be configuration. Verifying an Apple identity token needs only the bundle ID as the `aud` claim; Team ID is for generating a client secret, which slice 005 deliberately avoids. Omitting it silently contradicts the handoff; wiring it up adds a code path with no caller. Documenting it as unused is honest and costs a comment |
| 2026-08-31 | `.dockerignore` excludes `App/` and `docs/` | Ship the whole repository as build context | The build context is uploaded to the daemon on every build. The app tree contains `DerivedData` and `.xcuserstate` files the server image can never need |
| 2026-08-31 | CI runs `check-spdx.sh` and `check-layer-imports.sh` in **both** workflows | Run them in `server.yml` only | The layer-import boundary is an app concern and the SPDX boundary is a whole-repository one. Running them in one workflow means a change under `App/**` skips both checks, which is precisely where the layer-import check matters most |

## 7. Sub-Slices

Not split — delivered as a single slice. The Dockerfile and the CI workflows are separable on paper, but `server.yml` builds and pushes the image, so splitting them produces a workflow with no image or an image nothing proves.

## 8. Testing Strategy

- **Unit / Integration:** none new. This slice ships packaging, and its tests are the acceptance criteria above.
- The two criteria that carry real weight are the **negative** ones: a `Shared` file importing CoreGraphics must fail `server.yml`, and a source-only edit must not bust the resolve layer. Both are run once, by hand, on a throwaway branch, and the evidence pasted into the commit. A caching claim nobody measured is a caching claim that is wrong.
- **Test targets required:** none new. `Server/Tests/ServerTests/` from slice 001 is what `swift test` runs in CI.

## 9. Keeping this document true

This slice is done when the page describes what was actually built — not when the code works. The discipline is **ordering**: the write happens *before* the thing it describes, so it sits on the critical path instead of after it, where it gets skipped.

| Before you… | Write this first |
|---|---|
| implement a decision | the Section 6 row, including what you rejected |
| start work | flip status in the master checklist |
| stop on a blocker | the Active Blockers row |
| build on a spike | that spike's Result section |
| widen scope | Section 3, and `depends_on` on any slice that is now affected |

And in the same commit as the code, not a follow-up: **commit this file alongside it**, with the slice id in the commit subject (`003: add docker image and CI`).

Nothing checks any of this. That is the point of putting the writes first — a write you have to do to proceed is one you do; a write you are supposed to do afterwards is one you do not.

## 10. Definition of Done

- [ ] Acceptance criteria met
- [ ] Tests passing, in a target that exists
- [ ] Every `covers:` requirement satisfied, or forked with a decision row
- [ ] Decision log written as you went, not reconstructed
- [ ] Pre-flight completed and drift resolved
- [ ] Master checklist row current
- [ ] `next_slice`'s `depends_on` reflects what actually shipped, not what was planned
- [ ] Both link directions checked: this page's `next_slice` and `004`'s `previous_slice`

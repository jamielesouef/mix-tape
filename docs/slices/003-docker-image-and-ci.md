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
- `.dockerignore` excluding `**/.build`, `DerivedData/`, `App/`, `docs/` and `.git` — the app tree is a large context that the server image never needs. **The glob matters:** a bare `.build/` matches only the repository root, and the vendored dependency tree under `Server/.build/checkouts/` would upload on every build

**Scope widened during pre-flight — the app project file.** Pinning `app.yml` turned out to be impossible without touching `App/`, which this slice as drafted never did. The project was written by Xcode 27 in `objectVersion = 90`, which no stable hosted runner image can open, and its iOS deployment target was `27.0` against a documented `iOS 26+`. Both are now in scope:

- `App/MixTape.xcodeproj/project.pbxproj` — `objectVersion` and `preferredProjectObjectVersion` lowered to `77`, and `IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET` set to `26.0` on both configurations. Owner-decided during this slice's pre-flight; see Section 6
- `CLAUDE.md` — the interim "no feature newer than Swift 6.2 in `Shared/` or `Server/`" constraint stops being interim and gains `App/`, and the toolchain paragraph is corrected to describe what CI actually pins rather than what the local machine happens to run
- `001-repo-skeleton-and-version.md` — its pre-flight line about recording the local toolchain version is updated to point at this slice's pins

**Scope widened a second time, during the build — the app's two test targets.** `app.yml` runs `xcodebuild test`, and running it for the first time in this project's life showed that `MixTapeTests` and `MixTapeUITests` **cannot run at all**: slice 001 created them as empty directories, and an `.xctest` bundle with no compiled sources produces no executable. A workflow whose test job can only fail is not a workflow, and a job passing with zero executed tests is the false green the testing rules exist to forbid. So this slice writes the two tests slice 001's own Section 8 specified and never delivered — the `VersionResponseDTO` round-trip through `MixTapeJSON`, and one XCUITest driven off accessibility identifiers:

- `App/Tests/MixTapeTests/VersionResponseDTOTests.swift`
- `App/Tests/MixTapeUITests/VersionScreenUITests.swift`

That is the whole of the addition. Writing further tests here would be taking work from the slices that own the behaviour.

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

- [x] **002** — opened. `scripts/check-spdx.sh` exists, exits `0` over 24 Swift files and exits `1` on a violation; all four of its failure cases were demonstrated when 002 ran. No fork, so both workflows call it as planned.
- [x] **S001** — spike, **answered 2026-09-01 and favourable. The fallback was not taken.** Two `FileMiddleware` instances on two roots coexist on Hummingbird 2.26.0, and the middleware calls `next` before looking for a file, so it cannot shadow a route. Music and cache stay independent roots: `docker-compose.yml` mounts them separately and ladder **L1**'s seam is intact. No soft blocker to log — the answer landed before this slice started, which is what the checklist's "run S001 and S002 before slice 003" line was for.
- [x] Its state matches what this slice assumed when drafted. 002 shipped what 003 expected; S001 confirmed the assumed layout rather than changing it.
- [x] **Build-stage image pinned, and the Xcode pin with it.** Walked in the order this list specifies:
  1. **Does a `swift:6.4-noble` tag exist? No.** Docker Hub's tag API returns `404` for `6.4-noble`. `6.3-noble` returns `200` and `6.2-noble` returns `200`.
  2. So the build stage **stays `swift:6.2-noble`**, and `Shared/` and `Server/` are held to Swift 6.2 features permanently rather than as an interim. `6.3-noble` existing is recorded and deliberately not taken — see the decision row.
  3. **`app.yml` pins `macos-26` with Xcode 26.6**, and this cost more than a version string: the project file had to be downgraded first. Details and the owner's decision are in Section 6; the discovery is in the checklist's Drift Log.
- [x] Architecture standards doc re-read: `docs/plan/v1-architecture.md` section 7, Build.

**Drift found:** two items, both in the app project file, both logged in the checklist's Drift Log and both resolved by an owner decision during this pre-flight rather than deferred.

1. **The project was in Xcode 27's `objectVersion = 90` format.** No stable hosted runner image can open it — GitHub's `macos-26` image carries Xcode 26.0.1 through 26.6, and the only image with Xcode 27 is the `xcode-27` **public preview**. Pinning CI to a preview image is not a pin. Resolved: the project is downgraded to `objectVersion = 77`.
2. **`IPHONEOS_DEPLOYMENT_TARGET` was `27.0`** while `CLAUDE.md` and the plan both say **iOS 26+**, and `MACOSX_DEPLOYMENT_TARGET` was `26.6` — so the two platforms did not even agree with each other. Almost certainly an Xcode 27 template default nobody chose. Resolved: both are `26.0`.

**One thing this pre-flight could not verify, and it is honest to say so.** The repository has **no GitHub remote**, so no workflow has ever run. The owner chose to create a **private** repository during this slice, which is what turns the three CI acceptance criteria from unprovable into provable. Until that push happens they stay unticked.

## 5. Acceptance Criteria

- [x] `docker build .` at the repository root produces an image. Cold build **2m 19.6s**; runtime image **931 MB**, of which almost all is `ffmpeg` and its codec dependencies.
- [x] `docker run --rm -p 8080:8080 mixtape` starts, and `/version` returns `200`. Body `{"serverVersion":"0.1.0","claimed":false,"apiVersion":1}`, `Content-Type: application/json; charset=utf-8`. (`curl` to localhost is blocked by this session's sandbox, so the probe is `http.client` — same request, same assertion.)
- [x] **Layer caching is proven, not assumed.** The first attempt was a false positive worth recording: `touch`ing a source file changed **nothing**, because Docker's `COPY` cache key is content, not mtime — every layer came back `CACHED` and the ordering was never exercised. The real measurement appended a comment to `Server/Sources/Server/MixTapeServer.swift` and rebuilt: `RUN swift package resolve` **CACHED**, `COPY Server/Sources` **not cached**, total **49.4s** against the cold **2m 19.6s**. The comment was removed immediately afterwards and `git diff` confirms the file is untouched.
- [x] The runtime image contains no Swift runtime. `docker run --rm --entrypoint sh mixtape -c 'ls /usr/lib/swift'` exits `2` with "No such file or directory". Also checked from the other direction: `ldd /usr/local/bin/Server` links **zero** Swift libraries.
- [x] `docker compose up` with a music directory bind-mounted read-only starts and answers `/version` with `200`. The read-only mount is asserted, not assumed — `touch /music/writetest` inside the container fails "Read-only file system". **This criterion earned its place**: it caught a defect nothing else would have, recorded in Section 6 — the state volume mounted `root`-owned and the unprivileged server could not write to it, while `/version` still answered `200`.
- [x] The build stage is `swift:6.2-noble`, the tag this slice's pre-flight pinned, with a decision row saying why `6.3-noble` was available and not taken. `grep "6\.1" Dockerfile` returns nothing.
- [ ] `server.yml` triggers on `Shared/**` and `app.yml` does too; a commit touching only `App/**` triggers `app.yml` and **not** `server.yml`. **Blocked on the first push** — the repository had no remote when this slice ran. To be verified on a real branch, per the criterion, never by reading the YAML.
- [ ] `server.yml` compiles `Shared` on Linux, and adding `import CoreGraphics` to a `Shared` file fails that job. **Blocked on the first push.** This is the negative test that makes `1.linux` binding, so it is run deliberately, not skipped.
- [x] **`app.yml` pins an explicit Xcode version** — `macos-26` with `sudo xcode-select -s /Applications/Xcode_26.6.app` — and the version is in the decision row beside the Docker tag. Pinning it forced the project-file downgrade; both are recorded there and in the Drift Log.
- [x] `README.md`'s quickstart is the real invocation and was written against the compose file that actually ran: clone, `MIXTAPE_HOST_MUSIC_DIR=… docker compose up -d`, then `curl -i localhost:8080/version`. The expected body is quoted so a reader knows what success looks like.
- [x] `docker-compose.yml` declares `MIXTAPE_APPLE_TEAM_ID` with a comment stating it is unused in v1 and why (plan conflict **C6**).

**Two additions this slice made to its own criteria**, because pinning the runner turned out to touch `App/`:

- [x] **The project still builds under both Xcodes after the downgrade**, on both destinations — four combinations, all `BUILD SUCCEEDED`: Xcode 26.6 (build `17F113`, the exact version the runner carries, installed locally at `/Applications/Xcode-26.6.0.app`) on iOS Simulator and macOS, and Xcode 27.0 on both. Checked afterwards that Xcode 27 had not rewritten the format: `objectVersion` and `preferredProjectObjectVersion` are both still `77`.
- [x] **`xcodebuild test` passes, with a non-zero executed-test count.** `** TEST SUCCEEDED **`, and the result bundle reports `totalTestCount = 2`, `passedTests = 2`, `failedTests = 0` — a green reporting zero executed tests is a failure, so the count is the assertion, not the exit code. Getting here took three distinct failures, each a real defect rather than a retry of the last: a deployment target of 26.6 that no available simulator runtime could satisfy, two test bundles colliding on an empty product name, and then bundles with no executable at all because the targets had no sources. The simulator resolver `app.yml` uses was dry-run separately and returned `iPhone 17 Pro`.

**One honest gap in this criterion.** The run above used the **selected** Xcode 27, not the pinned 26.6. Xcode 26.6 builds this project on both destinations, but it cannot drive a simulator on this machine: `CoreSimulator` is owned by whichever Xcode is `xcode-select`ed, so a per-command `DEVELOPER_DIR` leaves `xcodebuild -showdestinations` listing only a placeholder. Switching globally needs `sudo` and changes the owner's machine state for the sake of one check. **CI does not have this problem** — `app.yml` runs `sudo xcode-select -s` as its first step, so the runner's daemon matches its Xcode. The Xcode 26.6 test path is therefore proven by the workflow's first run and not before it.

## 6. Decision Log

**Write the row before you implement the decision, not after.** This is the whole mechanism. A decision log filled in at close is reconstructed from memory, and the rejected alternatives — the part the next slice's pre-flight actually needs — are exactly what memory loses first.

| Date | Decision | Alternatives rejected | Why |
|---|---|---|---|
| 2026-08-31 | Build stage is `swift:6.2-noble` (plan conflict **C5**) | `swift:6.1-noble`, copied from the handoff | `Shared` compiles under both server and app; the lower language level would win and pin the whole repository. **Resolved by the project owner.** The handoff's Dockerfile must not be copied verbatim |
| 2026-09-01 | **The build stage stays `swift:6.2-noble`, and the Swift 6.2 feature ceiling on `Shared/` and `Server/` stops being interim** | `swift:6.4-noble`, which the pre-flight was told to prefer; `swift:6.3-noble`, which does exist; keeping the ceiling described as "interim until 003" | Step 1 of the pre-flight asked whether a `6.4-noble` tag exists. It does not — Docker Hub returns `404`. `6.3-noble` returns `200`, so bumping there was available and was **rejected on the grounds that it buys nothing**: both manifests declare `swift-tools-version: 6.2`, **C5** was resolved by the owner at 6.2, and raising the container's ceiling only widens the gap between what compiles on the Mac and what compiles in CI without enabling a single thing the code wants. The ceiling's whole job is to be *lower* than the local toolchain so a 6.4-only construct fails in CI rather than shipping. `CLAUDE.md`'s wording changes from "until slice 003 pins the image" to the standing rule |
| 2026-09-01 | **The pushed image is `linux/amd64`, and `server.yml`'s Linux job runs inside the same `swift:6.2-noble` image the Dockerfile pins** | For the architecture: `linux/arm64`, which is what the owner's Mac builds natively; a multi-arch matrix, which is ladder **L2**'s v2 rung. For the toolchain: a `swift-setup` action on `ubuntu-latest`, or whatever Swift the runner image ships | **The architecture is the owner's answer** — no document records which NAS this targets, and it is a fact nobody could derive. `amd64` covers the common Synology and QNAP case. Deploying is out of this slice's scope so a wrong guess would cost nothing here, which is precisely why it was worth settling now rather than discovering on the NAS. The seam is unchanged: the `platforms:` input on the buildx step. **The container choice is the more consequential half.** `1.linux` is the requirement this slice makes binding, and it is only binding if CI compiles `Shared` under the *same* Swift the image ships. A setup action pins a version in a second place that can drift from the Dockerfile silently, which is the one failure this job exists to catch |
| 2026-09-01 | **`app.yml` resolves the test simulator at runtime with `xcrun simctl`, rather than naming a device in the YAML** | Hardcode a device name and OS, e.g. `platform=iOS Simulator,name=iPhone 17,OS=26.5`; use `generic/platform=iOS Simulator` | A generic destination **builds but never runs a test**, which would make the job green while proving nothing — the same shape as the stale-bundle false green the testing rules warn about. A hardcoded device name is the other trap: GitHub rotates the runner image roughly monthly, and the day a device is renamed or dropped the job fails with a destination error that reads as a project problem. Three lines of `simctl` resolve whatever iPhone the image actually has, so the pin is on **Xcode 26.6**, which this slice decided, and not on a device list nobody controls |
| 2026-09-01 | **Both test targets gain `PRODUCT_NAME = "$(TARGET_NAME)"`, on both configurations** | Delete the empty test targets and let a later slice recreate them; set an explicit literal product name per target; leave it and let CI report the failure | **A pre-existing defect, surfaced by this slice and attributed before being fixed.** `xcodebuild test` failed with `Multiple commands produce …/MixTape.app/PlugIns/.xctest` — neither test target declared `PRODUCT_NAME`, so both resolved to an empty one and both tried to write the same bundle path. **Checked whether the project-format downgrade caused it: it did not.** Restoring the original `objectVersion = 90` file and re-running produced the identical error, so this arrived with slice 001, which created the targets and verified them with `xcodebuild build` — a command that never links a test bundle. Deleting the targets was rejected because slice 001's own Testing Strategy commits every later slice to them existing. `$(TARGET_NAME)` rather than a literal, so a rename cannot reintroduce the collision |
| 2026-09-01 | **The image creates `/var/lib/mixtape/data` and `/var/lib/mixtape/cache` and chowns them to the `mixtape` user before `USER` switches**, so a fresh named volume inherits that ownership | Run the container as `root`; have the server `mkdir` its own directories at boot and hope the mount point is writable; mount a host directory and tell the reader to `chown` it themselves in the quickstart | **Found by the `docker compose up` acceptance criterion, which is the entire reason that criterion is worth running.** `/version` answered `200`, so the container looked healthy — but `mkdir /var/lib/mixtape/data` inside it failed `Permission denied`. Docker initialises an empty named volume from the image's contents *and ownership* at that path; with nothing there, the mount point is `root`-owned and the unprivileged `mixtape` user cannot write to it. Nothing in v1 notices, because slice 001's `claimed` flag only checks for a file's **absence**. The first thing to break would have been slice 005's `owner.json` write — pairing failing on the NAS, against an image that passed every check this slice has. Running as `root` was rejected outright for a network service pointed at a personal library; a boot-time `mkdir` cannot fix a directory it has no permission to create; and pushing a `chown` into the quickstart makes the reader do the image's job |
| 2026-09-01 | **The build stage copies `Server/Tests` as well as `Server/Sources`, in its own layer after the sources** | Give the `ServerTests` target an explicit `path:` in the manifest so SwiftPM stops inferring one; drop the test target from the manifest for container builds | The first `docker build` failed outright: `error: 'server': target 'ServerTests' has overlapping sources`. With `Tests/` absent from the context, SwiftPM's path inference for `ServerTests` falls back onto `Sources/Server` and the two targets collide — the manifest is simply invalid in a tree missing a directory it never mentions. Editing the manifest to work around a copy that was omitted is fixing the wrong file, and the container is where `swift test` will eventually run in CI anyway. **Its own `COPY` line, placed after the sources**, so a test-only edit leaves the source layer cached |
| 2026-09-01 | **`app.yml` pins `runs-on: macos-26` and selects Xcode 26.6 explicitly, and the project file is downgraded to `objectVersion = 77` to make that possible** | `runs-on: xcode-27`, the only image carrying the local Xcode; leaving the runner unpinned; skipping `app.yml` until GitHub's Xcode 27 image is stable | The pre-flight's step 3 asks for a runner carrying the local Xcode **or** a recorded version the app is held to. The first is only available as a **public preview** image (`xcode-27`, Xcode 27.0 beta 4, build `27A5228h`), and a preview image is the opposite of a pin — GitHub can change or retire it, and "whatever the preview happens to be today" is exactly the silent, moving language level this criterion exists to prevent. Taking the stable `macos-26` image meant the project could not stay in Xcode 27's format, so **the owner chose to downgrade** rather than accept the preview or defer app CI. `preferredProjectObjectVersion` is lowered alongside `objectVersion`, because that is the setting that otherwise lets Xcode 27 rewrite the format back to 90 the next time the project is opened. Xcode 26.6 is installed locally at `/Applications/Xcode-26.6.0.app` — the same version the runner carries — so the downgrade is proven on this machine before CI ever sees it. The runner's own path is `/Applications/Xcode_26.6.app`, and `app.yml` uses that one |
| 2026-09-01 | **Deployment targets are `iOS 26.0` and `macOS 26.0`** | Keep `IPHONEOS_DEPLOYMENT_TARGET = 27.0` and raise the documents to match; keep the mismatch and log it for later | **Owner decision, taken during this slice's pre-flight.** The project said iOS `27.0` and macOS `26.6` — the two platforms disagreed with each other, and both disagreed with `CLAUDE.md` and the plan, which say iOS 26+ and macOS 26+. Nothing in the codebase uses an iOS 27 API, so the higher target was buying nothing and cutting off every iOS 26 device. Lowering it makes the project agree with the two documents that already described it, which is why no document changes |
| 2026-09-01 | **Both workflows also carry a `workflow_dispatch` trigger** | Leave push and pull_request only, and force the first run with a throwaway commit touching a filtered path | Found on the first push: GitHub does **not** evaluate a path-filtered `push` trigger when the push *creates* the branch, because there is no base commit to diff against. So a repository whose very first push contains both workflows runs neither of them, and the workflows sit unproven with nothing wrong in them. A throwaway commit would fix that run and nothing else. `workflow_dispatch` fixes it permanently and pays for itself again whenever GitHub rotates a runner image and CI needs re-running against unchanged code |
| 2026-09-01 | **The remote is `jamielesouef/mix-tape`, not `mixtape`** | Push onto the existing `mixtape` repository; rename the old one out of the way and take the name | A private repository named `mixtape` **already existed** on the account — an unrelated iOS-only attempt from March 2024, non-empty, with its own history. Pushing this tree onto it needs a force-push over unrelated history, which is not a thing to do on someone's behalf to save a hyphen. Renaming the old one was offered and declined. **Owner chose the new name.** Nothing in the repository encodes it: `server.yml` uses `${{ github.repository }}` for the GHCR tags, so the image path follows the remote automatically and a later rename costs nothing |
| 2026-09-01 | **The GitHub repository is created private for now** | Public immediately, which is what the handoff's "open source from the first public commit" anticipates; no remote at all, leaving CI unprovable | **Owner decision.** Slice 002 exists precisely so the first public commit is safe, and it has landed — so going public is available whenever the owner wants it, and the licence work is not the thing holding it back. Private today buys the CI proof this slice needs without making that call under time pressure. Nothing in the repository depends on visibility; flipping it later is a settings change and no code moves |
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

- [ ] Acceptance criteria met — **all but the three that need CI to have run.** The repository had no remote when this slice started; `jamielesouef/mix-tape` now exists and the first push is what closes them
- [ ] Tests passing, in a target that exists — **the targets existed and could not run.** Fixed here: `PRODUCT_NAME` added to both, and the two tests slice 001's Section 8 specified were written. Ticked once CI runs them
- [x] Every `covers:` requirement satisfied, or forked with a decision row — `7.build` in full; `1.linux` becomes binding the moment `server.yml` first runs, which is the same push
- [x] Decision log written as you went, not reconstructed — nine rows, six of them added mid-build because real failures forced real decisions: the missing `Tests` copy, the root-owned state volume, the runner pin, the simulator resolver, the empty test bundles and the repository name
- [x] Pre-flight completed and drift resolved — two drift items found and both resolved by an owner decision rather than deferred; a third surfaced during the build and is in the checklist's Drift Log
- [x] Master checklist row current
- [x] `next_slice`'s `depends_on` reflects what actually shipped — 004 depends on 003 and **S002**, both unchanged by anything here. S002's fallback landed in 004 when the spike was answered, not now
- [x] Both link directions checked: this page's `next_slice` (`004`) and `004`'s `previous_slice` (`003`)

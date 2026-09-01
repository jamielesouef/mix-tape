---
spike_id: "S002"
title: Does `swift run Server` serve a local music folder on macOS with no container?
timebox: 2 hours
unblocks: ["001", "004"]
created: 2026-08-31
---

# S002 — `swift run Server` on macOS, no container

[Master Checklist](MASTER-CHECKLIST.md) · Unblocks: [001-repo-skeleton-and-version](001-repo-skeleton-and-version.md), [004-library-scan-to-manifest](004-library-scan-to-manifest.md)

> **Status, owner and the answer summary live in the master checklist, not here.** This page holds the question, the method, the fallback and the evidence. One fact, one home.

## 1. Question

Does `swift run Server` build and run the identical server binary on macOS, against a local music folder, with no Docker container — including finding `ffprobe` and `ffmpeg` on the host?

Two parts, both needed for a yes:

1. Does the Hummingbird 2 server package build and boot on macOS at all, or does it carry a Linux-only dependency?
2. Does the scan path find the ffmpeg tools on a developer Mac, given the plan bundles them in the Docker image and says nothing about the host?

## 2. Why this blocks

The handoff states this as a preserved property: *"Docker is a packaging step, not a dev loop… the moment a container is needed to test a change, iteration speed dies."* Every server-side slice from 004 onwards is built and tested through this loop. If it does not hold, the loop for slices 004, 004a, 005, 006, 008 and 009 becomes a container rebuild per change, and each of those slices needs a different testing strategy written into its Section 8.

Part 2 is the part likely to bite. The plan invokes `ffprobe` and `ffmpeg` as a bundled binary in the Docker image and never says how the macOS run finds them. If it hardcodes `/usr/local/bin/ffprobe`, it breaks on Apple silicon (Homebrew installs to `/opt/homebrew/bin`); if it relies on `PATH`, a `Process` launched from Xcode does not inherit a login shell's `PATH`. This is a real, concrete failure, not a hypothetical — and it changes slice 004's design, which is why it is a spike and not a note.

## 3. Cheapest experiment that answers it

Two halves. The first half needs slice 001 to exist; run it as slice 001's own verification. The second half can run today with a throwaway.

**Part 1 — server boots (run during slice 001):**

- [ ] `cd Server && swift run Server`
- [ ] `curl -i localhost:8080/version` → `200` with a `VersionResponseDTO` body
- [ ] Record the macOS version, Xcode version and toolchain used

**Part 2 — tool discovery (run now, throwaway):**

- [ ] `which ffprobe ffmpeg` in a login shell; record the absolute paths
- [ ] Write a ~20 line throwaway in `/tmp/ffprobe-spike/` that runs `ffprobe -v quiet -print_format json -show_format -show_streams <file>` through `Foundation.Process` and prints the JSON
- [ ] Run it twice: once from a terminal, once from an Xcode scheme with no custom environment. **The two must both succeed.** If only the terminal run works, the answer is unfavourable for part 2
- [ ] Record whether `Process.executableURL` needed an absolute path, and whether `/usr/bin/env ffprobe` resolved it

**Explicitly not doing:** no scanning logic, no tag mapping, no DTO construction — that is slice 004's job. This spike prints raw JSON and stops.

## 4. Timebox

`2 hours`. On expiry: stop, record what you learned, and take the fallback in Section 5. An overrunning spike is itself an answer — the thing is harder than the design assumed.

## 5. Fallback if the answer is unfavourable

Decided **before** running the experiment, so the result does not get argued with.

> **If part 1 fails (server will not build or boot on macOS):** the dev loop becomes `docker compose up --build` with the source directory bind-mounted, added to slice 003 as a `compose.dev.yml`. The iteration-speed cost is recorded as accepted, not silently absorbed, and every server slice's Section 8 says "container loop" rather than `swift run`.
>
> **If part 2 fails (tools not found from a `Process`):** slice 004 gains a required `MIXTAPE_FFPROBE_PATH` and `MIXTAPE_FFMPEG_PATH` pair of environment variables, defaulting to `ffprobe` and `ffmpeg` resolved through `/usr/bin/env` and overridable to an absolute path. The Docker image sets neither, because the bundled tools are already on `PATH` there. This is a two-line change in slice 004 if it is decided now, and a debugging session if it is discovered later.

## 6. Result

| | |
|---|---|
| **Answer (part 1)** | **Yes.** `swift run Server` builds and boots Hummingbird 2 on macOS with no container, and `GET /version` returns `200` with a real `VersionResponseDTO` body |
| **Answer (part 2)** | **No — and it fails exactly the way Section 2 predicted.** `ffprobe` and `ffmpeg` are at `/opt/homebrew/bin` (Apple silicon Homebrew), which is **not** on the PATH a process launched outside a login shell inherits. Resolving through `/usr/bin/env ffprobe` works from a terminal and **fails under a scrubbed PATH**; an absolute path works in both. The pre-decided fallback in Section 5 therefore applies in full: slice 004 gains `MIXTAPE_FFPROBE_PATH` and `MIXTAPE_FFMPEG_PATH` |
| **Evidence** | `swift run Server` log: `2026-08-31T19:21:16+1000 info Hummingbird: [HummingbirdCore] Server started and listening on 0.0.0.0:8080`. `curl`-equivalent (`python3 -m urllib.request`, `curl` itself was blocked by this session's sandbox) against `http://localhost:8080/version`: HTTP `200`, headers `Content-Type: application/json; charset=utf-8`, body `{"apiVersion":1,"serverVersion":"0.1.0","claimed":false}` — decodes to `VersionResponseDTO` with `apiVersion == 1`. Toolchain: Swift 6.4 (swiftlang-6.4.0.33.1), Xcode 27.0 (27A5252f), macOS host target arm64-apple-macosx26.0 |
| **Evidence (part 2)** | `which ffprobe ffmpeg` → `/opt/homebrew/bin/ffprobe`, `/opt/homebrew/bin/ffmpeg`; `ffprobe version 9.0.1`. A ~35-line throwaway executable ran `ffprobe -v quiet -print_format json -show_format -show_streams` through `Foundation.Process` twice, once per resolution strategy, under two environments. **Login-shell PATH:** strategy A (`/usr/bin/env ffprobe`) `status=0 bytes=1858`; strategy B (absolute `/opt/homebrew/bin/ffprobe`) `status=0 bytes=1858`. **Scrubbed PATH** (`env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin`, the honest proxy for an Xcode-launched process — a real Xcode scheme could not be driven from this session, and it is recorded as a proxy, not as the Xcode run): strategy A `status=127 bytes=0`, strategy B `status=0 bytes=1858` |
| **The detail slice 004 must not miss** | The failure is **silent by default**. `/usr/bin/env` cannot throw a Swift error for a binary it fails to find — the `Process` launches fine, `env` itself exits `127` and writes nothing to stdout. A `do`/`catch` around `process.run()` catches nothing. Slice 004 must check `terminationStatus` and treat a non-zero exit as a hard failure, or a scan on a machine with no reachable `ffprobe` produces an empty manifest and no error anywhere — the same shape of fault as the checks in the Drift Log that report success while the thing they protect is broken |
| **Date** | part 1 2026-08-31, part 2 2026-09-01 |

## 7. Consequences

- [x] Decision recorded in the decision log of: `001-repo-skeleton-and-version.md` (part 1 — recorded in that slice's **pre-flight**, where it was run, rather than its decision log) and `004-library-scan-to-manifest.md` (part 2, added 2026-09-01)
- [x] Affected slices updated (scope, dependencies, acceptance criteria): **004** takes the fallback — two new configuration variables, plus a `terminationStatus` check and an acceptance criterion for the scrubbed-PATH case. **001** needs nothing further; part 1 already landed there. **003** needs nothing: the Docker image puts both tools on `PATH`, so the variables stay unset there and the default resolution is the one that works
- [x] Master checklist spike row set to `Answered`, with the one-line answer
- [x] Throwaway code deleted. It lived in the session scratchpad (`…/scratchpad/ffprobe-spike`), not `/tmp/ffprobe-spike`
- [x] If the answer invalidated a prior decision: **no.** The plan never stated how a macOS run finds the tools — this spike answered an open question rather than contradicting a decision, so no Drift Log row. The unfavourable half was pre-decided in Section 5 and is applied as written

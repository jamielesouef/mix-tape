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
| **Answer (part 1)** | |
| **Answer (part 2)** | |
| **Evidence** | command output, error, doc link — not "it seemed to work" |
| **Date** | |

## 7. Consequences

- [ ] Decision recorded in the decision log of: `001-repo-skeleton-and-version.md` (part 1) and `004-library-scan-to-manifest.md` (part 2)
- [ ] Affected slices updated (scope, dependencies, acceptance criteria): 001, 003, 004
- [ ] Master checklist spike row set to `Answered`, with the one-line answer
- [ ] Throwaway code deleted from `/tmp/ffprobe-spike`, or moved somewhere clearly marked as a spike artefact
- [ ] If the answer invalidated a prior decision: Architecture Drift Log updated

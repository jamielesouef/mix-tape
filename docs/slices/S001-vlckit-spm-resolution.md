---
spike_id: "S001"
title: Does VLCKit resolve as an SPM binary dependency with iOS 26 and tvOS 26 simulator slices and link into MixtapeInfrastructure under Swift 6 mode with MainActor default isolation?
timebox: 2 hours
unblocks: ["007"]
created: 2026-09-03
---

# S001 — Does VLCKit resolve as an SPM binary dependency with iOS 26 and tvOS 26 simulator slices and link into MixtapeInfrastructure under Swift 6 mode with MainActor default isolation?

[Master Checklist](MASTER-CHECKLIST.md) · Unblocks: [007-video-vlc](007-video-vlc.md)

> **Status, owner and the answer summary live in the master checklist, not here.** This page holds the question, the method, the fallback and the evidence. One fact, one home.

## 1. Question

Does declaring VLCKit as an SPM dependency of `MixtapeInfrastructure` resolve and build for both the iOS 26 and tvOS 26 simulator destinations, under `.swiftLanguageMode(.v6)` and `.defaultIsolation(MainActor.self)` (decision 15) on that target — yes or no, and if no, does the vendored-xcframework fallback resolve instead?

## 2. Why this blocks

Slice 007 is the only place `VLCKit` is meant to be imported anywhere in the codebase (§7: `VLCPlayerController` is "the only file that imports `VLCKit`"), and it is the slice that adds the dependency edge `MixtapeInfrastructure` → VLCKit to `MixtapeKit/Package.swift`. Slice 001 deliberately left that edge out of `Package.swift` — its decision log records the edge as "deferred to 007, pending S001's spike answer" — precisely so slice 001 does not carry a gate failure that belongs to this question.

Three distinct answers redesign three different things:

- **Resolves as a plain SPM dependency.** Slice 007's Section 3 adds one `.package(url:...)` line and one `.product(name: "VLCKit", ...)` target dependency. No further redesign.
- **Does not resolve as SPM, but the vendored xcframework does.** Slice 007's Section 3 instead adds a local `binaryTarget(path:)` pointing at a checked-in or externally-fetched `.xcframework`, and the repo gains wherever that binary lives (tracked or referenced by a fetch script) — a different footprint than a plain manifest edit, decided here rather than invented mid-slice.
- **Neither resolves for tvOS.** `PlaybackMethod.directVLC` has no player on tvOS, which contradicts §1's "direct play (AVPlayer), direct play (VLCKit), or HLS transcode" being one capability across both platforms this spike is not authorised to redesign around — it is a decision-level change that goes back to the human, per this spike's own fallback (Section 5) and the plan's instruction that a spike answering "no tvOS slice at all" escalates rather than resolves.

If nothing is confirmed here, slice 007 starts by discovering mid-slice which of the three shapes its own `Package.swift` edit and its own scope list should have taken — the situation this spike exists to prevent.

## 3. Cheapest experiment that answers it

Throwaway package, never the real repo — `MixtapeKit/Package.swift` gains no edit until this spike closes.

- [ ] Create a throwaway SPM package outside `build-run` (e.g. under the scratchpad), one library target, `swiftSettings: [.defaultIsolation(MainActor.self), .swiftLanguageMode(.v6)]` on that target to match decision 15's actual setting rather than SPM defaults.
- [ ] Add VLCKit as a `.package(url:)` dependency (resolve the current SPM-distributed coordinate for the iOS/tvOS xcframework slices; there is more than one community distribution — record which one was tried).
- [ ] One file, `import VLCKit`, referencing a single symbol (e.g. constructing a `VLCMediaPlayer`) so the linker is actually exercised, not just the manifest resolver.
- [ ] `swift build` for the package alone, to isolate a manifest-resolution failure from a destination-specific build failure.
- [ ] `xcodebuild build` (or `swift build -Xswiftc -sdk ...` equivalent) against an iOS 26 simulator destination.
- [ ] `xcodebuild build` against a tvOS 26 simulator destination (`xcrun simctl list devices available` first — this machine has no pinned `OS=26.0` runtime, per `CLAUDE.md`'s standing rule).
- [ ] Record the exact resolver/build error, if any, not a paraphrase of it.
- [ ] Only if the SPM package fails to resolve or link on either destination: repeat the same one-symbol build against a local `binaryTarget(path:)` vendoring the `.xcframework` directly, both destinations.

**Explicitly not doing:** wiring `VLCPlayerController`, `VideoPlaybackService`, or any `VideoPlayerControlling` conformance; adding UI; touching `MixtapeKit/Package.swift` in the real repo; proving playback of any file. This spike answers whether the dependency resolves and links, not whether VLC plays media.

## 4. Timebox

2 hours. On expiry: stop, record what was learned, and take the fallback in Section 5 — an overrunning resolution attempt is itself the answer that VLCKit is harder to bring in than the design assumed.

## 5. Fallback if the answer is unfavourable

If the SPM package does not resolve or link cleanly on both simulator destinations under decision 15's settings: vendor the xcframework as a local `binaryTarget(path:)` in `MixtapeKit/Package.swift`, resolved in slice 007. This is pre-authorised and does not stall the run.

If no tvOS slice can be produced by either method — SPM or vendored — that is not this spike's fallback to take. It is a decision-level change (tvOS's `.directVLC` branch has no player) and goes back to the human rather than being resolved here.

## 6. Result

| | |
|---|---|
| **Answer** | |
| **Evidence** | |
| **Date** | |

## 7. Consequences

- [ ] Decision recorded in the decision log of: `007`
- [ ] Affected slices updated: 007's Section 3 dependency edge and `Package.swift` shape; 001's Ordering Note and decision-log row that deferred the edge, if the vendored fallback changes what "adding the edge" means
- [ ] Master checklist spike row set to `Answered`, with the one-line answer
- [ ] Throwaway code deleted, or moved somewhere clearly marked as a spike artefact
- [ ] If the answer invalidated a prior decision: Architecture Drift Log updated

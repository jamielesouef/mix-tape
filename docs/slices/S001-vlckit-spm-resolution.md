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

- [x] Create a throwaway SPM package outside `build-run` (e.g. under the scratchpad), one library target, `swiftSettings: [.defaultIsolation(MainActor.self), .swiftLanguageMode(.v6)]` on that target to match decision 15's actual setting rather than SPM defaults.
- [x] Add VLCKit as a `.package(url:)` dependency (resolve the current SPM-distributed coordinate for the iOS/tvOS xcframework slices; there is more than one community distribution — record which one was tried).
- [x] One file, `import VLCKit`, referencing a single symbol (e.g. constructing a `VLCMediaPlayer`) so the linker is actually exercised, not just the manifest resolver.
- [x] `swift build` for the package alone, to isolate a manifest-resolution failure from a destination-specific build failure.
- [x] `xcodebuild build` (or `swift build -Xswiftc -sdk ...` equivalent) against an iOS 26 simulator destination.
- [x] `xcodebuild build` against a tvOS 26 simulator destination (`xcrun simctl list devices available` first — this machine has no pinned `OS=26.0` runtime, per `CLAUDE.md`'s standing rule).
- [x] Record the exact resolver/build error, if any, not a paraphrase of it.
- [ ] Only if the SPM package fails to resolve or link on either destination: repeat the same one-symbol build against a local `binaryTarget(path:)` vendoring the `.xcframework` directly, both destinations. — not needed; the SPM package resolved and linked on both.

**Explicitly not doing:** wiring `VLCPlayerController`, `VideoPlaybackService`, or any `VideoPlayerControlling` conformance; adding UI; touching `MixtapeKit/Package.swift` in the real repo; proving playback of any file. This spike answers whether the dependency resolves and links, not whether VLC plays media.

## 4. Timebox

2 hours. On expiry: stop, record what was learned, and take the fallback in Section 5 — an overrunning resolution attempt is itself the answer that VLCKit is harder to bring in than the design assumed.

## 5. Fallback if the answer is unfavourable

If the SPM package does not resolve or link cleanly on both simulator destinations under decision 15's settings: vendor the xcframework as a local `binaryTarget(path:)` in `MixtapeKit/Package.swift`, resolved in slice 007. This is pre-authorised and does not stall the run.

If no tvOS slice can be produced by either method — SPM or vendored — that is not this spike's fallback to take. It is a decision-level change (tvOS's `.directVLC` branch has no player) and goes back to the human rather than being resolved here.

## 6. Result

| | |
|---|---|
| **Answer** | **Yes.** VLCKit resolves as a plain SPM binary dependency and links into a Swift 6 mode, `MainActor`-default-isolated target on both the iOS 26.5 and tvOS 26.5 simulators. The vendored `binaryTarget(path:)` fallback was not needed. Coordinate: the community package `https://github.com/tylerjonesio/vlckit-spm.git`, `exact: "3.6.0"` (VLCKit 3.6.0), product `VLCKitSPM`. VideoLAN ships no SPM manifest of its own, so this is the only SPM route. Two facts 007 must carry: the module name differs per platform (`import MobileVLCKit` on iOS, `import TVVLCKit` on tvOS, `VLCKit` only on macOS), so the single importing file needs `#if os(iOS)` / `#if os(tvOS)` around its import; and the artefact is a 778.7 MB zip of dynamic frameworks, pulled on every clean resolve. |
| **Evidence** | Throwaway package at `/Volumes/S990/Developer/personal/spike-scratch/S001-vlckit-spm` (outside this repo, kept as the spike artefact). `swift package resolve` downloaded `VLCKit-all.xcframework.zip` (778.7 MB, 195.91 s). The xcframework `Info.plist` lists `ios-arm64_i386_x86_64-simulator`, `ios-arm64_armv7_armv7s`, `tvos-arm64`, `tvos-arm64_x86_64-simulator`, `macos-arm64_x86_64`; `lipo -info` on the tvOS simulator binary: `x86_64 arm64`. `xcodebuild build -scheme VLCSpikeExe` against `platform=iOS Simulator,id=D7807C47-…` and `platform=tvOS Simulator,id=66521166-…` (both 26.5 runtimes) each ended `** BUILD SUCCEEDED **` with zero warnings, linking a real executable: `otool -L` shows `@rpath/MobileVLCKit.framework/MobileVLCKit` (iOS) and `@rpath/TVVLCKit.framework/TVVLCKit` (tvOS); `nm -u` on the object shows `_OBJC_CLASS_$_VLCMediaPlayer` undefined and `nm -arch arm64` on each simulator framework shows it defined. Host `swift build` also passed via the macOS slice. Full commands and output below. |
| **Date** | 2026-09-03 |

### Evidence detail

Toolchain: Xcode 27.0 (27A5252f), Swift 6.4 driver, `swift-tools-version: 6.2` manifest. Simulators: iPhone 17 Pro on iOS 26.5 (`D7807C47-6BB6-49A0-BE48-73531DF52C98`), Apple TV 4K (3rd generation) on tvOS 26.5 (`66521166-020B-43EB-A3F5-53605634D01A`). No iOS 26.0 or tvOS 26.0 runtime is installed; 26.5 is the closest.

Coordinate search, exact output:

```
$ git ls-remote --tags https://code.videolan.org/videolan/VLCKit-SPM.git
fatal: could not read Username for 'https://code.videolan.org': Device not configured   # repo does not exist
$ git ls-remote --tags https://github.com/videolan/VLCKit-SPM.git
remote: Repository not found.
$ git ls-remote --tags https://code.videolan.org/videolan/VLCKit.git | tail -2
31a5f067152dc4586e9072ea7a62088abf41e67c	refs/tags/4.0.0a8
455d9d2e8310c3075dd152f33a133a1bdd840ec5	refs/tags/4.0.0a8^{}
$ git show HEAD:Package.swift                 # shallow clone of the official repo at tag 4.0.0a21
fatal: path 'Package.swift' does not exist in 'HEAD'
$ git ls-remote --tags https://github.com/tylerjonesio/vlckit-spm.git
e932bbd488872fdb74f6654d28c2f291eae03daf	refs/tags/3.6.0
d9006002f372c5bcf72a5ef24ebd02f89ef9f4fe	refs/tags/v3.5.1
42789b71940f550a7ff01d26067a907f8c36bdfa	refs/tags/v3.6.0.b10
```

Throwaway manifest (the shape 007 copies onto `MixtapeInfrastructure`):

```swift
// swift-tools-version: 6.2
dependencies: [
    .package(url: "https://github.com/tylerjonesio/vlckit-spm.git", exact: "3.6.0"),
],
targets: [
    .target(
        name: "VLCSpike",
        dependencies: [.product(name: "VLCKitSPM", package: "vlckit-spm")],
        swiftSettings: [.defaultIsolation(MainActor.self), .swiftLanguageMode(.v6)]
    ),
    .executableTarget(name: "VLCSpikeExe", dependencies: ["VLCSpike"], swiftSettings: [/* same */]),
]
```

The one importing file. A bare `import VLCKit` compiles on the macOS host and fails on both simulators because the iOS and tvOS slices are named `MobileVLCKit.framework` and `TVVLCKit.framework`. Observed, same line on both destinations:

```
$ xcodebuild build -scheme VLCSpike -destination 'platform=iOS Simulator,id=D7807C47-…'    # and platform=tvOS Simulator,id=66521166-…
Sources/VLCSpike/VLCSpike.swift:1:8: error: Unable to resolve module dependency: 'VLCKit' (in target 'VLCSpike' from project 'VLCSpike')
** BUILD FAILED **
```

With the conditional imports:

```swift
#if os(iOS)
import MobileVLCKit
#elseif os(tvOS)
import TVVLCKit
#else
import VLCKit
#endif

public final class VLCSpike {
    public let player = VLCMediaPlayer()
    public init() {}
}
```

Build and link, exact output lines:

```
$ swift package resolve
Downloaded https://github.com/tylerjonesio/vlckit-spm/releases/download/3.6.0/VLCKit-all.xcframework.zip (195.91s)
$ ls .build/artifacts/vlckit-spm/VLCKit-all/VLCKit-all.xcframework/
ios-arm64_armv7_armv7s/MobileVLCKit.framework   ios-arm64_i386_x86_64-simulator/MobileVLCKit.framework
tvos-arm64/TVVLCKit.framework                   tvos-arm64_x86_64-simulator/TVVLCKit.framework
macos-arm64_x86_64/VLCKit.framework
$ lipo -info …/tvos-arm64_x86_64-simulator/TVVLCKit.framework/TVVLCKit
Architectures in the fat file: … are: x86_64 arm64
$ swift build                                   # macOS host
Build complete! (13.53 sec.)
$ xcodebuild build -scheme VLCSpikeExe -destination 'platform=iOS Simulator,id=D7807C47-6BB6-49A0-BE48-73531DF52C98' -derivedDataPath ../S001-dd-ios
Ld …/Debug-iphonesimulator/VLCSpikeExe normal (in target 'VLCSpikeExe-product' from project 'VLCSpike')
** BUILD SUCCEEDED **
$ xcodebuild build -scheme VLCSpikeExe -destination 'platform=tvOS Simulator,id=66521166-020B-43EB-A3F5-53605634D01A' -derivedDataPath ../S001-dd-tvos
Ld …/Debug-appletvsimulator/VLCSpikeExe normal (in target 'VLCSpikeExe-product' from project 'VLCSpike')
** BUILD SUCCEEDED **
$ grep -c 'warning:' S001-ios-exe-build.log S001-tvos-exe-build.log
S001-ios-exe-build.log:0
S001-tvos-exe-build.log:0
$ otool -L …/Debug-iphonesimulator/VLCSpikeExe | grep -i vlc
	@rpath/MobileVLCKit.framework/MobileVLCKit (compatibility version 1.0.0, current version 1.0.0)
$ otool -L …/Debug-appletvsimulator/VLCSpikeExe | grep -i vlc
	@rpath/TVVLCKit.framework/TVVLCKit (compatibility version 1.0.0, current version 1.0.0)
$ nm -u …/Debug-appletvsimulator/VLCSpike.o | grep -i vlc
_OBJC_CLASS_$_VLCMediaPlayer
$ nm -arch arm64 …/tvos-arm64_x86_64-simulator/TVVLCKit.framework/TVVLCKit | grep '_OBJC_CLASS_\$_VLCMediaPlayer$'
0000000001d3cc18 S _OBJC_CLASS_$_VLCMediaPlayer
```

Not proven here, by design: that VLC plays anything; that the 778.7 MB artefact download is acceptable for whatever CI eventually replaces the deleted workflows (record it when CI returns); anything about the 4.0 alpha line, which has no SPM manifest.

Timebox: started 18:18, answered 18:29 of the 2 h.

## 7. Consequences

- [x] Decision recorded in the decision log of: `007`
- [x] Affected slices updated: 007's Section 3 dependency edge and `Package.swift` shape, and its "only file that imports VLCKit" wording (the module is `MobileVLCKit` / `TVVLCKit` per platform). 001 unchanged: the fallback was not taken, so "adding the edge" still means a manifest edit.
- [x] Master checklist spike row set to `Answered`, with the one-line answer
- [x] Throwaway code kept at `/Volumes/S990/Developer/personal/spike-scratch/S001-vlckit-spm` outside this repo, marked as a spike artefact; nothing under `build-run` carries it
- [x] If the answer invalidated a prior decision: Architecture Drift Log updated — n/a, no prior decision invalidated

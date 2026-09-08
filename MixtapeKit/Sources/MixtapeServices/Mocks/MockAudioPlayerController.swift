//  MockAudioPlayerController.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG
    import Foundation
    import MixtapeDomain
    import MixtapeInfrastructure

    /// An `AudioPlayerControlling` that does nothing audible, for previews. `Stub*` doubles for tests
    /// live in the test targets.
    public final class MockAudioPlayerController: AudioPlayerControlling {
        public var onPositionChange: ((Duration) -> Void)?
        public var onEnded: (() -> Void)?
        public var onFailure: ((MixtapeError) -> Void)?
        public var onRemotePlay: (() -> Void)?
        public var onRemotePause: (() -> Void)?
        public var onRemoteNext: (() -> Void)?
        public var onRemotePrevious: (() -> Void)?
        public var onRemoteSeek: ((Duration) -> Void)?

        public init() {}

        public func load(url _: URL) {}
        public func play() {}
        public func pause() {}
        public func seek(to _: Duration) {}
        public func stop() {}
        public func updateNowPlaying(_: NowPlayingInfo) {}
        public func setNextTrackEnabled(_: Bool) {}
    }
#endif

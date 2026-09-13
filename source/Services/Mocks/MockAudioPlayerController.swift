//  MockAudioPlayerController.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

#if DEBUG
    import Foundation

    final class MockAudioPlayerController: AudioPlayerControlling {
        var onPositionChange: ((Duration) -> Void)?
        var onEnded: (() -> Void)?
        var onFailure: ((MixtapeError) -> Void)?
        var onRemotePlay: (() -> Void)?
        var onRemotePause: (() -> Void)?
        var onRemoteNext: (() -> Void)?
        var onRemotePrevious: (() -> Void)?
        var onRemoteSeek: ((Duration) -> Void)?

        init() {}

        func load(url _: URL) {}
        func play() {}
        func pause() {}
        func seek(to _: Duration) {}
        func stop() {}
        func updateNowPlaying(_: NowPlayingInfo) {}
        func setNextTrackEnabled(_: Bool) {}
    }
#endif

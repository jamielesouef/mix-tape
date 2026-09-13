//  StubAudioPlayerController.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure

@MainActor
final class StubAudioPlayerController: AudioPlayerControlling {
    var onPositionChange: ((Duration) -> Void)?
    var onEnded: (() -> Void)?
    var onFailure: ((MixtapeError) -> Void)?
    var onRemotePlay: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteNext: (() -> Void)?
    var onRemotePrevious: (() -> Void)?
    var onRemoteSeek: ((Duration) -> Void)?

    private(set) var loadedURLs: [URL] = []
    private(set) var nextEnabledHistory: [Bool] = []
    private(set) var stopCount = 0
    private(set) var nowPlayingHistory: [NowPlayingInfo] = []
    private(set) var seeks: [Duration] = []

    func load(url: URL) {
        loadedURLs.append(url)
    }

    func play() {}
    func pause() {}
    func seek(to position: Duration) {
        seeks.append(position)
    }

    func stop() {
        stopCount += 1
    }

    func updateNowPlaying(_ info: NowPlayingInfo) {
        nowPlayingHistory.append(info)
    }

    func setNextTrackEnabled(_ enabled: Bool) {
        nextEnabledHistory.append(enabled)
    }

    func finishTrack() {
        onEnded?()
    }
}

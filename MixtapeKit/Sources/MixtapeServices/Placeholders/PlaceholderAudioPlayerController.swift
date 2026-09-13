//  PlaceholderAudioPlayerController.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure

final class PlaceholderAudioPlayerController: AudioPlayerControlling {
    var onPositionChange: ((Duration) -> Void)?
    var onEnded: (() -> Void)?
    var onFailure: ((MixtapeError) -> Void)?
    var onRemotePlay: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteNext: (() -> Void)?
    var onRemotePrevious: (() -> Void)?
    var onRemoteSeek: ((Duration) -> Void)?

    func load(url _: URL) {}
    func play() {}
    func pause() {}
    func seek(to _: Duration) {}
    func stop() {}
    func updateNowPlaying(_: NowPlayingInfo) {}
    func setNextTrackEnabled(_: Bool) {}
}

//  AudioPlayerControlling.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain

/// The audio player seam. `MusicPlayerService` owns one of these and drives it; the lock-screen and
/// remote events arrive back through the `onRemote…` callbacks (engineering doc §6/§7).
@MainActor
public protocol AudioPlayerControlling: AnyObject {
    var onPositionChange: ((Duration) -> Void)? { get set }
    var onEnded: (() -> Void)? { get set }
    var onFailure: ((MixtapeError) -> Void)? { get set }
    var onRemotePlay: (() -> Void)? { get set }
    var onRemotePause: (() -> Void)? { get set }
    var onRemoteNext: (() -> Void)? { get set }
    var onRemotePrevious: (() -> Void)? { get set }
    var onRemoteSeek: ((Duration) -> Void)? { get set }

    func load(url: URL)
    func play()
    func pause()
    func seek(to position: Duration)
    func stop()
    func updateNowPlaying(_ info: NowPlayingInfo)
    func setNextTrackEnabled(_ enabled: Bool)
}

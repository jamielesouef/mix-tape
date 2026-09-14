//  RemoteCommandCenter.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import MediaPlayer

/// Wires the system's remote transport surfaces — control centre, lock screen, headset
/// buttons — to the player's transport actions.
final class RemoteCommandCenter {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onSeek: ((Duration) -> Void)?

    init() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNext?()
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPrevious?()
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            self?.onSeek?(.seconds(event.positionTime))
            return .success
        }
    }

    func setNextTrackEnabled(_ enabled: Bool) {
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = enabled
    }
}

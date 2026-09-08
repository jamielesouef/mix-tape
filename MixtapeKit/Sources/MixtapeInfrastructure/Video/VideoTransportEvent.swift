//  VideoTransportEvent.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Foundation

/// A transport change the player itself reports (slice 014, Triage 11). The player is the one
/// source of these — a pause from AVKit's controls, from the VLC overlay's button, from the Siri
/// Remote or from `VideoPlaybackService.togglePlayPause()` all arrive here the same way, so the
/// service has one place to move `status` and send the one report §6 asks for.
public nonisolated enum VideoTransportEvent: Sendable, Equatable {
    case paused
    case resumed
    /// Seek completion, carrying the position the player landed on.
    case seeked(Duration)
}

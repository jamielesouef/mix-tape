//  VLCPlayerIdentifiers.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

/// The VLC overlay's identifiers (decision 17). They live here, not with Presentation's enums,
/// because the overlay is Infrastructure and may not import Presentation.
enum VLCPlayerIdentifiers {
    static let playPauseButton = "vlcPlayer.playPauseButton"
    static let scrubber = "vlcPlayer.scrubber"
}

//  RouteChangeAction.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import AVFoundation

/// Whether an audio route change should pause playback — true only when the active output
/// device disappeared (headphones unplugged, and the like), false for every other reason
/// and for a raw value the current OS no longer recognises.
nonisolated func shouldPause(forRouteChangeReason reasonValue: UInt) -> Bool {
    AVAudioSession.RouteChangeReason(rawValue: reasonValue) == .oldDeviceUnavailable
}

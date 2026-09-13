//  AudioInterruptionAction.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import AVFoundation

nonisolated enum AudioInterruptionAction: Equatable {
    case pause
    case resume
    case none
}

nonisolated func audioInterruptionAction(
    type: AVAudioSession.InterruptionType,
    options: AVAudioSession.InterruptionOptions,
) -> AudioInterruptionAction {
    switch type {
    case .began: .pause
    case .ended: options.contains(.shouldResume) ? .resume : .none
    @unknown default: .none
    }
}

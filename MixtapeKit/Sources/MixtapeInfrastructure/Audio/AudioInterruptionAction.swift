//  AudioInterruptionAction.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import AVFoundation

/// What `AudioPlayerController` does in response to an `AVAudioSession.interruptionNotification`
/// (slice 023). A begin always pauses; an end resumes only if the system hints it is appropriate
/// (`.shouldResume`), otherwise playback stays paused until the user acts.
public nonisolated enum AudioInterruptionAction: Equatable {
    case pause
    case resume
    case none
}

/// Pure and `nonisolated` so it is unit-testable without a live `AVAudioSession` (fork F1's
/// precedent: `redactingURLs`, slice 019). Takes the system's own enums as input rather than a
/// re-declared local pair, so a test can construct the exact values the notification carries.
public nonisolated func audioInterruptionAction(
    type: AVAudioSession.InterruptionType,
    options: AVAudioSession.InterruptionOptions,
) -> AudioInterruptionAction {
    switch type {
    case .began: .pause
    case .ended: options.contains(.shouldResume) ? .resume : .none
    @unknown default: .none
    }
}

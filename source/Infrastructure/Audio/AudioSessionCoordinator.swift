//  AudioSessionCoordinator.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import AVFoundation

/// Owns the shared `AVAudioSession` lifecycle: activating it once, watching for
/// interruptions, route changes and media-services resets, and turning each into the
/// transport action it implies.
///
/// Configuration is idempotent and lazy — nothing happens until the first
/// `configureIfNeeded()`, which loading a track triggers.
@MainActor
final class AudioSessionCoordinator {
    var onPause: (() -> Void)?
    var onPlay: (() -> Void)?
    /// Fired when the media services reset and playback must reconfigure and reload.
    var onReconfigureNeeded: (() -> Void)?

    private var didConfigure = false
    private var interruptionObserver: (any NSObjectProtocol)?
    private var routeChangeObserver: (any NSObjectProtocol)?
    private var mediaResetObserver: (any NSObjectProtocol)?

    init() {
        observeInterruptions()
        observeRouteChanges()
        observeMediaServicesReset()

        AppLogger.playback
            .info("audio session interruption/route-change/reset observers registered")
    }

    isolated deinit {
        for observer in [interruptionObserver, routeChangeObserver, mediaResetObserver] {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    /// Activates the session on first call; a later call is a no-op until a reset clears it.
    func configureIfNeeded() {
        guard didConfigure == false else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)

            didConfigure = true

            AppLogger.playback.info("audio session configured: category .playback, active")
        } catch {
            AppLogger.playback
                .error("audio session configuration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo

            guard let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else {
                return
            }

            let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0

            MainActor.assumeIsolated {
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    private func observeRouteChanges() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let reasonKey = AVAudioSessionRouteChangeReasonKey

            guard let reasonValue = notification.userInfo?[reasonKey] as? UInt else {
                return
            }

            MainActor.assumeIsolated {
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }
    }

    private func observeMediaServicesReset() {
        mediaResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMediaServicesReset()
            }
        }
    }

    private func handleInterruption(typeValue: UInt, optionsValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

        switch audioInterruptionAction(type: type, options: options) {
        case .pause: onPause?()
        case .resume: onPlay?()
        case .none: break
        }
    }

    private func handleRouteChange(reasonValue: UInt) {
        guard shouldPause(forRouteChangeReason: reasonValue) else {
            return
        }

        onPause?()
    }

    private func handleMediaServicesReset() {
        didConfigure = false

        AppLogger.playback.error("media services reset; reconfiguring audio session")

        onReconfigureNeeded?()
    }
}

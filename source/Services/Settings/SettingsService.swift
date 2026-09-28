//  SettingsService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Observation

@MainActor
@Observable
final class SettingsService {
    // MARK: - Properties

    private(set) var settings: LocalSettings

    private let store: any LocalSettingsStoreProtocol

    // MARK: - Initialization

    init(store: any LocalSettingsStoreProtocol) {
        self.store = store
        settings = store.load()
    }

    // MARK: - Public API

    func setAlbumOrder(_ order: AlbumOrder) {
        settings.albumOrder = order
        persist()
    }

    func setWhenAlbumEnds(_ preference: WhenAlbumEndsPreference) {
        settings.whenAlbumEnds = preference
        persist()
    }

    func setStreamingQuality(_ quality: StreamingQuality) {
        settings.streamingQuality = quality
        persist()
    }

    func setDownloadsWiFiOnly(_ enabled: Bool) {
        settings.downloadsWiFiOnly = enabled
        persist()
    }

    // MARK: - Private

    private func persist() {
        store.save(settings)
    }
}

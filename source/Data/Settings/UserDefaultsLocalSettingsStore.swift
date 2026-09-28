//  UserDefaultsLocalSettingsStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// `UserDefaults` is documented thread-safe for concurrent reads and writes, so vouching for
/// its `Sendable` conformance here reflects that guarantee rather than silencing a warning.
struct UserDefaultsLocalSettingsStore: LocalSettingsStoreProtocol, @unchecked Sendable {
    private static let key = "mixtape.localSettings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LocalSettings {
        guard let data = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode(StoredSettings.self, from: data)
        else {
            return LocalSettings()
        }

        return decoded.settings
    }

    func save(_ settings: LocalSettings) {
        guard let data = try? JSONEncoder().encode(StoredSettings(settings: settings)) else {
            return
        }

        defaults.set(data, forKey: Self.key)
    }

    // MARK: - Private

    private struct StoredSettings: Codable {
        let albumOrder: AlbumOrder
        let whenAlbumEnds: WhenAlbumEndsPreference
        let streamingQuality: StreamingQuality
        let downloadsWiFiOnly: Bool

        init(settings: LocalSettings) {
            albumOrder = settings.albumOrder
            whenAlbumEnds = settings.whenAlbumEnds
            streamingQuality = settings.streamingQuality
            downloadsWiFiOnly = settings.downloadsWiFiOnly
        }

        var settings: LocalSettings {
            LocalSettings(
                albumOrder: albumOrder,
                whenAlbumEnds: whenAlbumEnds,
                streamingQuality: streamingQuality,
                downloadsWiFiOnly: downloadsWiFiOnly
            )
        }
    }
}

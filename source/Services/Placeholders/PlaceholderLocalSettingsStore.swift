//  PlaceholderLocalSettingsStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct PlaceholderLocalSettingsStore: LocalSettingsStoreProtocol {
    func load() -> LocalSettings {
        LocalSettings()
    }

    func save(_: LocalSettings) {}
}

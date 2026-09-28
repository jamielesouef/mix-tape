//  LocalSettingsStoreProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

nonisolated protocol LocalSettingsStoreProtocol: Sendable {
    func load() -> LocalSettings
    func save(_ settings: LocalSettings)
}

//  MockSettingsService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

#if DEBUG

    @MainActor
    enum MockSettingsService {
        static func make(settings: LocalSettings = LocalSettings()) -> SettingsService {
            SettingsService(store: MockLocalSettingsStore(settings: settings))
        }
    }
#endif

//  SettingsService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

extension SettingsService {
    static let placeholder: SettingsService = {
        #if DEBUG
            return MockSettingsService.make()
        #else
            return SettingsService(store: PlaceholderLocalSettingsStore())
        #endif
    }()
}

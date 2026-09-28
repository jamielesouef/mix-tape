//  MockLocalSettingsStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

#if DEBUG

    final class MockLocalSettingsStore: LocalSettingsStoreProtocol, @unchecked Sendable {
        private let lock = NSLock()
        private var stored: LocalSettings

        init(settings: LocalSettings = LocalSettings()) {
            stored = settings
        }

        func load() -> LocalSettings {
            lock.withLock { stored }
        }

        func save(_ settings: LocalSettings) {
            lock.withLock { stored = settings }
        }
    }
#endif

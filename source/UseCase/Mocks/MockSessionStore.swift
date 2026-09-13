//  MockSessionStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

#if DEBUG
    import Foundation

    public final nonisolated class MockSessionStore: SessionStoreProtocol, @unchecked Sendable {
        private let lock = NSLock()
        private var stored: UserSession?
        private var failure: (any Error)?

        public init(session: UserSession? = nil, failure: (any Error)? = nil) {
            stored = session
            self.failure = failure
        }

        public var session: UserSession? {
            lock.withLock { stored }
        }

        public func load() throws -> UserSession? {
            try lock.withLock {
                if let failure {
                    throw failure
                }
                return stored
            }
        }

        public func save(_ session: UserSession) throws {
            try lock.withLock {
                if let failure {
                    throw failure
                }
                stored = session
            }
        }

        public func clear() throws {
            try lock.withLock {
                if let failure {
                    throw failure
                }
                stored = nil
            }
        }
    }
#endif

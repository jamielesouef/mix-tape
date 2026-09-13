//  AppLogger.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import os

nonisolated struct AppLogger: Sendable {
    static let network = AppLogger(category: "network")
    static let playback = AppLogger(category: "playback")
    static let auth = AppLogger(category: "auth")

    private let logger: Logger

    private init(category: String) {
        logger = Logger(subsystem: "mobi.jamie.mixtape", category: category)
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

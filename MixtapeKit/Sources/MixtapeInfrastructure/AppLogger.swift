//  AppLogger.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import os

/// One subsystem, three categories (engineering doc §7). Messages are logged `.public`;
/// never interpolate a token or a credential into one (decision 45).
public nonisolated struct AppLogger: Sendable {
    public static let network = AppLogger(category: "network")
    public static let playback = AppLogger(category: "playback")
    public static let auth = AppLogger(category: "auth")

    private let logger: Logger

    private init(category: String) {
        logger = Logger(subsystem: "mobi.jamie.mixtape", category: category)
    }

    public func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

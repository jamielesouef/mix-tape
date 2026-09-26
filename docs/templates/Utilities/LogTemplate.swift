// TEMPLATE — the one logging call. ONE per app. Copy once, delete this header.
//
// Layer: Utilities/AppLog.swift
//
// - Every log line in the app goes through this type. `print()` never
//   appears; a second logger never appears. Forward to a remote sink
//   (crash reporter, analytics) from inside `error` if the app has one, so
//   callers stay one line.
// - Caseless enum, static only, no state.
// - The subsystem is a literal, not `Bundle.main.bundleIdentifier`: a
//   stateless type reads no ambient global. Replace the literal with your
//   bundle identifier.

import OSLog

enum AppLog {
    // MARK: - Private

    private static let logger = Logger(subsystem: "com.example.app", category: "app")

    // MARK: - Levels

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}

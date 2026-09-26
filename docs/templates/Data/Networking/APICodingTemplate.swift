// TEMPLATE — shared coder config. ONE per app. Copy once, delete this header.
//
// Layer: Data/Networking/APICoding.swift
//
// - The one JSONDecoder / JSONEncoder configuration for the API's wire
//   convention (snake_case here). Every decode and every request body goes
//   through these two factories, so a DTO's `CodingKeys` only ever names the
//   keys that don't follow the convention.
// - Tests decode fixtures with `APICoding.makeDecoder()` too. A test that
//   builds its own decoder can pass while the app's decoder rejects the same
//   payload.
// - Factories, not shared instances: `JSONDecoder` is a reference type and
//   not `Sendable`, so a fresh one per call is what keeps `send` `@concurrent`.

import Foundation

enum APICoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

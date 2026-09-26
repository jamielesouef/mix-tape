// TEMPLATE — shared status validation and decode. ONE per app. Copy once, delete this header.
//
// Layer: Data/Networking/APIResponseHandling.swift
//
// - Generic over the feature's `APIError`, so one body serves every feature.
//   Status-code mapping lives here and nowhere else.
// - `decode` takes the decoder as a parameter, defaulting to the one shared
//   config. An endpoint with a different wire convention passes a different
//   decoder; it never gets a second `decode`.
// - Exhaustive by design: the `switch` over the status code ends in
//   `default: .server` because HTTP status codes are an open set, not an
//   enum. That is the one place `default` is correct.
// - Decode failure is logged with the type name so the log says which DTO
//   drifted from the wire, then rethrown as the feature's `.decoding`.

import Foundation

enum APIResponseHandling {
    // MARK: - Validate

    static func validate<E: APIError>(
        _ response: URLResponse,
        data: Data,
        as errorType: E.Type
    ) throws(E) -> Data {
        guard let http = response as? HTTPURLResponse else {
            throw .network
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw error(forStatus: http.statusCode)
        }

        return data
    }

    // MARK: - Decode

    static func decode<T: Decodable, E: APIError>(
        _ type: T.Type,
        from data: Data,
        using decoder: JSONDecoder = APICoding.makeDecoder(),
        as errorType: E.Type
    ) throws(E) -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            AppLog.error("Decoding \(type) failed: \(error)")
            throw .decoding
        }
    }

    // MARK: - Private

    private static func error<E: APIError>(forStatus code: Int) -> E {
        switch code {
        case 401: .unauthorised
        case 403: .forbidden
        case 404: .notFound
        default: .server
        }
    }
}

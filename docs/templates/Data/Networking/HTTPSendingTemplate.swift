// TEMPLATE — the one `send`. ONE per app. Copy once, delete this header.
//
// Layer: Data/Networking/HTTPSending.swift
//
// - Generic over the DTO and the feature's `APIError`. Every transport in
//   the app calls this. Nobody writes a second `send`.
// - `@concurrent` (Swift 6.2+) guarantees the request AND the decode run on
//   the cooperative pool, never on the caller's actor. Without it, under the
//   "nonisolated async inherits the caller's isolation" model, a service
//   awaiting a repository would drag `JSONDecoder.decode` onto the main
//   thread. Decoding is synchronous CPU work; that is the UI stall this rule
//   exists to prevent.
// - Two failure paths, both logged once with method, path and status, then
//   rethrown as the feature's typed error. `URLSession` errors become
//   `.network`; validate and decode already throw `E`.
// - `AppLog` is the app's single logging entry point (Utilities/LogTemplate.swift).

import Foundation

enum HTTPSending {
    // MARK: - Send

    @concurrent
    static func send<T: Decodable, E: APIError>(
        _ request: URLRequest,
        urlSession: URLSession,
        errorType: E.Type,
        as type: T.Type
    ) async throws(E) -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            logFailure(error, request: request, statusCode: nil)
            throw .network
        }

        do {
            let payload = try APIResponseHandling.validate(response, data: data, as: E.self)
            return try APIResponseHandling.decode(type, from: payload, as: E.self)
        } catch {
            logFailure(error, request: request, statusCode: (response as? HTTPURLResponse)?.statusCode)
            throw error
        }
    }

    // MARK: - Private

    private static func logFailure(_ error: any Error, request: URLRequest, statusCode: Int?) {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path() ?? "?"
        AppLog.error("\(method) \(path) failed: HTTP \(statusCode?.description ?? "none"): \(error)")
    }
}

// TEMPLATE — URL catalogue and header builder. ONE per app. Copy once, delete this header.
//
// Layer: Data/Networking/APICatalogue.swift
//
// - Every endpoint the app talks to is a `static func` here returning a URL.
//   A feature ADDS a function; it never declares a second catalogue under
//   its own prefix. Two hosts? Two `baseURL` statics in this one type.
// - `headers` is the one place the app's fixed headers, the optional Bearer
//   token and any per-call extras are merged. Every `*Request` builder calls
//   it, so a header change is one edit.
// - The force-unwrap on `baseURL` is safe because the literal is on the same
//   line. That visibility is what makes a `!` acceptable.

import Foundation

enum APICatalogue {
    // MARK: - Hosts

    static let baseURL = URL(string: "https://api.example.com")!

    // MARK: - Endpoints

    static func exampleFeatureItems(language: String) -> URL {
        baseURL
            .appending(path: "v1/items")
            .appending(queryItems: [URLQueryItem(name: "language", value: language)])
    }

    // MARK: - Headers

    static func headers(token: String?, extra: [String: String]) -> [String: String] {
        let base = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        let auth = token.map { ["Authorization": "Bearer \($0)"] } ?? [:]

        return base
            .merging(extra) { _, new in new }
            .merging(auth) { _, new in new }
    }
}

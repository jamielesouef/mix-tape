// TEMPLATE — per-feature URLRequest builder. Copy, rename, delete this header.
//
// Layer: Data/<Feature>/<Name>Request.swift
//
// One of the two per-feature Data types (the other is the DTO). Pure static
// functions from inputs to a `URLRequest`. No session, no state, no `await`.
// - URLs come from the shared catalogue (Data/Networking/APITemplate.swift).
// - Headers come from the shared `headers` builder. `extraHeaders` is the
//   seam a test uses to tag a request for its stub `URLProtocol`, and the
//   app uses for per-build headers. It always flows through.
// - A request with a body encodes it with the shared `APICoding.makeEncoder()`
//   and throws the feature's typed `.encoding` on failure. See
//   FunctionsTemplate.swift shape 3 for that body.

import Foundation

enum ExampleFeatureRequest {
    // MARK: - Method

    private enum Method: String {
        case get = "GET"
    }

    // MARK: - Requests

    static func items(
        language: String,
        token: String?,
        extraHeaders: [String: String]
    ) -> URLRequest {
        make(
            url: APICatalogue.exampleFeatureItems(language: language),
            method: .get,
            token: token,
            extraHeaders: extraHeaders
        )
    }

    // MARK: - Private

    private static func make(
        url: URL,
        method: Method,
        token: String?,
        extraHeaders: [String: String]
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = APICatalogue.headers(token: token, extra: extraHeaders)
        return request
    }
}

// TEMPLATE — per-feature HTTP transport. Copy, rename, delete this header.
//
// Layer: Data/<Feature>/<Name>HTTPTransport.swift
//
// A transport is split by JOB, and only two jobs are per feature:
//
//   Per feature (new file each time):
//     - DTOs                        Data/<Feature>/DTO/*.swift
//     - `*Request` builder          Data/<Feature>/<Name>Request.swift
//     - this class + its protocol   sends only
//
//   Shared, ONE per app (Data/Networking/, add a case or a static func, never fork):
//     - URL catalogue               APICatalogue
//     - Coder config                APICoding
//     - Error protocol              APIError
//     - Validate + decode           APIResponseHandling
//     - The send + failure log      HTTPSending.send
//
// This class is deliberately thin: read the token, build the request via the
// feature's builder, call the shared `send`. It is NOT `@MainActor`.
// `extraHeaders` defaults to empty and is the seam a test uses to tag
// requests for its stub `URLProtocol`.

import Foundation

final class ExampleFeatureHTTPTransport: ExampleFeatureHTTPTransportProtocol, Sendable {
    // MARK: - Private

    private let urlSession: URLSession
    private let tokenProvider: any AuthTokenProviding
    private let extraHeaders: [String: String]

    // MARK: - Init

    init(
        urlSession: URLSession = .shared,
        tokenProvider: any AuthTokenProviding,
        extraHeaders: [String: String] = [:]
    ) {
        self.urlSession = urlSession
        self.tokenProvider = tokenProvider
        self.extraHeaders = extraHeaders
    }

    // MARK: - ExampleFeatureHTTPTransportProtocol

    func fetchItems(language: String) async throws(ExampleFeatureError) -> ExampleFeatureItemsResponseDTO {
        let request = ExampleFeatureRequest.items(
            language: language,
            token: tokenProvider.currentToken(),
            extraHeaders: extraHeaders
        )
        return try await HTTPSending.send(
            request,
            urlSession: urlSession,
            errorType: ExampleFeatureError.self,
            as: ExampleFeatureItemsResponseDTO.self
        )
    }
}

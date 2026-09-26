// TEMPLATE — HTTP transport unit test. Copy, rename, delete this header.
//
// Layer: <TestTarget>/Data/<Name>HTTPTransportTests.swift
// Pair with: StubURLProtocolTemplate.swift and Fixtures/PayloadFixturesTemplate.swift
//
// - Never the real network. `URLSessionConfiguration.ephemeral` with the
//   stub `URLProtocol`, keyed by a fresh `UUID()` marker per test.
// - THE MARKER MUST REACH THE TRANSPORT. `makeSUT` passes it through
//   `extraHeaders`, the same constructor real code uses. Without it the
//   stub's `canInit` never claims the request and the test goes to the
//   network.
// - Assert the REQUEST the transport built (URL, query, method, headers) as
//   well as the RESPONSE it decoded. A transport test that checks only the
//   decoded result misses a header regression entirely.
// - Status-code -> error mapping is one parameterised `@Test(arguments:)`.
// - `await #expect(throws:)` for the typed-throws call, never `do/catch`
//   with a manual `Issue.record`.

import Foundation
import Testing
@testable import ExampleApp

@Suite("ExampleFeatureHTTPTransport", .tags(.networking))
struct ExampleFeatureHTTPTransportTests {
    // MARK: - Helpers

    private func makeStubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ExampleFeatureStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeSUT(marker: String, token: String? = nil) -> ExampleFeatureHTTPTransport {
        ExampleFeatureHTTPTransport(
            urlSession: makeStubSession(),
            tokenProvider: ClosureAuthTokenProvider { token },
            extraHeaders: [ExampleFeatureStubURLProtocol.markerHeader: marker]
        )
    }

    private func stub(marker: String, statusCode: Int = 200, body: Data) {
        ExampleFeatureStubURLProtocol.stub(marker: marker) { request in
            guard let url = request.url else {
                return (nil, nil, URLError(.badURL))
            }

            return (body, HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil), nil)
        }
    }

    // MARK: - Request shape

    @Test("fetchItems targets the items endpoint with the language query and a Bearer token")
    func fetchItemsBuildsTheExpectedRequest() async throws {
        let marker = UUID().uuidString
        stub(marker: marker, body: Data(ExampleFeaturePayloadFixtures.items.utf8))
        defer { ExampleFeatureStubURLProtocol.removeStub(marker: marker) }
        let sut = makeSUT(marker: marker, token: "stub-token")

        _ = try await sut.fetchItems(language: "en")

        let request = try #require(ExampleFeatureStubURLProtocol.capturedRequest(for: marker))
        #expect(request.url?.path() == "/v1/items")
        #expect(request.url?.query() == "language=en")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer stub-token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("fetchItems omits Authorization when signed out")
    func fetchItemsOmitsBearerWhenSignedOut() async throws {
        let marker = UUID().uuidString
        stub(marker: marker, body: Data(ExampleFeaturePayloadFixtures.items.utf8))
        defer { ExampleFeatureStubURLProtocol.removeStub(marker: marker) }
        let sut = makeSUT(marker: marker, token: nil)

        _ = try await sut.fetchItems(language: "en")

        let request = try #require(ExampleFeatureStubURLProtocol.capturedRequest(for: marker))
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // MARK: - Status mapping

    @Test(
        "non-2xx status codes map to the matching ExampleFeatureError",
        arguments: [
            (401, ExampleFeatureError.unauthorised),
            (403, ExampleFeatureError.forbidden),
            (404, ExampleFeatureError.notFound),
            (500, ExampleFeatureError.server),
            (503, ExampleFeatureError.server)
        ]
    )
    func statusCodeMapsToError(statusCode: Int, expected: ExampleFeatureError) async throws {
        let marker = UUID().uuidString
        stub(marker: marker, statusCode: statusCode, body: Data())
        defer { ExampleFeatureStubURLProtocol.removeStub(marker: marker) }
        let sut = makeSUT(marker: marker)

        await #expect(throws: expected) {
            _ = try await sut.fetchItems(language: "en")
        }
    }

    // MARK: - Error paths

    @Test("a URLSession transport error maps to .network")
    func urlSessionErrorMapsToNetwork() async throws {
        let marker = UUID().uuidString
        ExampleFeatureStubURLProtocol.stub(marker: marker) { _ in
            (nil, nil, URLError(.notConnectedToInternet))
        }
        defer { ExampleFeatureStubURLProtocol.removeStub(marker: marker) }
        let sut = makeSUT(marker: marker)

        await #expect(throws: ExampleFeatureError.network) {
            _ = try await sut.fetchItems(language: "en")
        }
    }

    @Test("invalid JSON maps to .decoding")
    func invalidJSONMapsToDecoding() async throws {
        let marker = UUID().uuidString
        stub(marker: marker, body: Data("not json".utf8))
        defer { ExampleFeatureStubURLProtocol.removeStub(marker: marker) }
        let sut = makeSUT(marker: marker)

        await #expect(throws: ExampleFeatureError.decoding) {
            _ = try await sut.fetchItems(language: "en")
        }
    }

    // MARK: - Decoding

    @Test("fetchItems decodes the snake_case envelope fixture")
    func fetchItemsDecodesFixture() async throws {
        let marker = UUID().uuidString
        stub(marker: marker, body: Data(ExampleFeaturePayloadFixtures.items.utf8))
        defer { ExampleFeatureStubURLProtocol.removeStub(marker: marker) }
        let sut = makeSUT(marker: marker)

        let response = try await sut.fetchItems(language: "en")

        #expect(response.data.count == 2)
        #expect(response.data.first?.ownerID == 42)
        #expect(response.message == "OK")
    }
}

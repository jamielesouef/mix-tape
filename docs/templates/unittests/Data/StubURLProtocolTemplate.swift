// TEMPLATE — marker-keyed stub URLProtocol. Copy, rename, delete this header.
//
// Layer: <TestTarget>/Data/<Name>StubURLProtocol.swift
//
// One per transport suite. Keyed by a marker HEADER (a fresh UUID per test)
// rather than by URL, so parallel tests never answer each other's requests.
// The transport's `extraHeaders` is how the marker gets onto the request.
//
// - `URLProtocol`'s entry points (`canInit`, `startLoading`) are synchronous
//   class methods, so an actor is impossible here. `Mutex` (OS 18+) guards
//   one registry struct; every access is a single `withLock`. This is the
//   one lock in the test target.
// - Handlers are `@Sendable` so the registry is `Sendable` and the static
//   `Mutex` is a legal Swift 6 global.
// - A handler returns `(Data?, HTTPURLResponse?, Error?)`. An error wins.
//   `HTTPURLResponse.init` is failable and is returned as the optional it
//   is; no force-unwrap.
//
// Usage from a suite:
//   let marker = UUID().uuidString
//   ExampleFeatureStubURLProtocol.stub(marker: marker) { request in (data, response, nil) }
//   defer { ExampleFeatureStubURLProtocol.removeStub(marker: marker) }
//   // build the transport with a URLSession whose protocolClasses is [Self]
//   // and extraHeaders: [ExampleFeatureStubURLProtocol.markerHeader: marker]
//   let captured = ExampleFeatureStubURLProtocol.capturedRequest(for: marker)

import Foundation
import Synchronization

final class ExampleFeatureStubURLProtocol: URLProtocol {
    // MARK: - Types

    typealias Handler = @Sendable (URLRequest) -> (Data?, HTTPURLResponse?, (any Error)?)

    private struct Registry {
        var handlers: [String: Handler] = [:]
        var capturedRequests: [String: URLRequest] = [:]
    }

    // MARK: - Registry

    static let markerHeader = "X-Test-Case"

    private static let registry = Mutex(Registry())

    static func stub(marker: String, handler: @escaping Handler) {
        registry.withLock { $0.handlers[marker] = handler }
    }

    static func removeStub(marker: String) {
        registry.withLock {
            $0.handlers[marker] = nil
            $0.capturedRequests[marker] = nil
        }
    }

    static func capturedRequest(for marker: String) -> URLRequest? {
        registry.withLock { $0.capturedRequests[marker] }
    }

    // MARK: - URLProtocol

    override static func canInit(with request: URLRequest) -> Bool {
        guard let marker = request.value(forHTTPHeaderField: markerHeader) else {
            return false
        }

        return registry.withLock { registry in
            guard registry.handlers[marker] != nil else {
                return false
            }

            registry.capturedRequests[marker] = request
            return true
        }
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let marker = request.value(forHTTPHeaderField: Self.markerHeader),
              let handler = Self.registry.withLock({ $0.handlers[marker] }) else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let (data, response, error) = handler(request)

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

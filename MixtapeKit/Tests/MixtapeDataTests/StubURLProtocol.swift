//  StubURLProtocol.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

/// Routes each request to the `StubServer` whose id the session stamped into a header, so
/// suites can run in parallel without sharing a handler.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let headerName = "X-Stub-Server"

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.headerName), let server = StubServer.registry.server(for: id) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        server.record(request)
        do {
            let (response, data) = try server.handle(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

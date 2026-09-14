//  StubURLProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let headerName = "X-Stub-Server"

    // Overrides URLProtocol's `class func` API; `static` cannot express an override.
    // swiftlint:disable:next static_over_final_class
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    // Overrides URLProtocol's `class func` API; `static` cannot express an override.
    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let id = request.value(forHTTPHeaderField: Self.headerName),
            let server = StubServer.registry.server(for: id) else {
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

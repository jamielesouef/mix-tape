//  StubImageURLProtocol.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

final class StubImageURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable () async -> (statusCode: Int, data: Data)

    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var handlers: [URL: Handler] = [:]

        func register(_ url: URL, handler: @escaping Handler) {
            lock.withLock { handlers[url] = handler }
        }

        func handler(for url: URL) -> Handler? {
            lock.withLock { handlers[url] }
        }
    }

    private static let registry = Registry()

    static func register(_ url: URL, handler: @escaping Handler) {
        registry.register(url, handler: handler)
    }

    static var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubImageURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return registry.handler(for: url) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let handler = Self.registry.handler(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        Task {
            let (statusCode, data) = await handler()
            guard let http = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
                client?.urlProtocol(self, didFailWithError: URLError(.unknown))
                return
            }
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

//  StubServer.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

final class StubServer: @unchecked Sendable {
    final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var servers: [String: StubServer] = [:]

        func register(_ server: StubServer) {
            lock.withLock { servers[server.id] = server }
        }

        func server(for id: String) -> StubServer? {
            lock.withLock { servers[id] }
        }
    }

    static let registry = Registry()

    let id = UUID().uuidString
    let session: URLSession
    private let lock = NSLock()
    private var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    private var recorded: URLRequest?
    private var recordedBody: String?

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [StubURLProtocol.headerName: id]
        session = URLSession(configuration: configuration)
        Self.registry.register(self)
    }

    var lastRequest: URLRequest? {
        lock.withLock { recorded }
    }

    func respond(status: Int, body: Data = Data()) {
        lock.withLock {
            handler = { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                return (response, body)
            }
        }
    }

    func respond(status: Int, json: String) {
        respond(status: status, body: Data(json.utf8))
    }

    func fail(_ code: URLError.Code) {
        lock.withLock { handler = { _ in throw URLError(code) } }
    }

    func record(_ request: URLRequest) {
        let body = Self.readBody(of: request)
        lock.withLock {
            recorded = request
            recordedBody = body
        }
    }

    func handle(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let handler = lock.withLock({ handler }) else { throw URLError(.unknown) }
        return try handler(request)
    }

    func lastBody() -> String? {
        lock.withLock { recordedBody }
    }

    private static func readBody(of request: URLRequest) -> String? {
        if let body = request.httpBody {
            return String(decoding: body, as: UTF8.self)
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

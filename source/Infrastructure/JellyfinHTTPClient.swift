//  JellyfinHTTPClient.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public nonisolated struct JellyfinHTTPClient: Sendable {
    public let session: URLSession
    public let deviceName: String

    private static let credentialPaths: Set<String> = [
        "/Users/AuthenticateByName", "/Users/AuthenticateWithQuickConnect",
    ]
    private static let quickConnectPaths: Set<String> = ["/QuickConnect/Enabled", "/QuickConnect/Initiate"]

    public init(session: URLSession, deviceName: String) {
        self.session = session
        self.deviceName = deviceName
    }

    public func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [], auth: AuthContext) async throws -> T {
        let request = try makeRequest(method: "GET", path: path, query: query, auth: auth, body: nil)
        let data = try await perform(request, path: path)
        return try decode(T.self, from: data)
    }

    public func post<T: Decodable & Sendable>(
        _ path: String, body: some Encodable & Sendable, query: [URLQueryItem] = [], auth: AuthContext,
    ) async throws -> T {
        let request = try makeRequest(method: "POST", path: path, query: query, auth: auth, body: encode(body))
        let data = try await perform(request, path: path)
        return try decode(T.self, from: data)
    }

    public func post(_ path: String, body: some Encodable & Sendable, query: [URLQueryItem] = [], auth: AuthContext) async throws {
        let request = try makeRequest(method: "POST", path: path, query: query, auth: auth, body: encode(body))
        _ = try await perform(request, path: path)
    }

    // MARK: - Request assembly

    func authorizationHeader(for auth: AuthContext) -> String {
        let device = deviceName.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"")
        var header = "MediaBrowser Client=\"mixtape\", Device=\"\(device)\", DeviceId=\"\(auth.deviceID)\", Version=\"\(auth.appVersion)\""
        if let token = auth.token {
            header += ", Token=\"\(token)\""
        }
        return header
    }

    private func makeRequest(method: String, path: String, query: [URLQueryItem], auth: AuthContext, body: Data?) throws -> URLRequest {
        guard var components = URLComponents(url: auth.baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw MixtapeError.transport(path)
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw MixtapeError.transport(path) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authorizationHeader(for: auth), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func perform(_ request: URLRequest, path: String) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw Self.map(error)
        }
        guard let http = response as? HTTPURLResponse else { throw MixtapeError.transport(path) }
        if let failure = Self.map(status: http.statusCode, path: path) {
            throw failure
        }
        return data
    }

    // MARK: - Mapping

    static func map(status: Int, path: String) -> MixtapeError? {
        switch status {
        case 200 ... 299:
            nil
        case 401 where credentialPaths.contains(path):
            .invalidCredentials
        case 401 where quickConnectPaths.contains(path):
            .quickConnectUnavailable
        case 401:
            .sessionExpired
        default:
            .transport(HTTPURLResponse.localizedString(forStatusCode: status))
        }
    }

    static func map(_ error: URLError) -> MixtapeError {
        switch error.code {
        case .cannotFindHost, .cannotConnectToHost, .timedOut:
            .serverUnreachable
        default:
            .transport(error.localizedDescription)
        }
    }

    // MARK: - JSON

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw MixtapeError.decoding
        }
    }

    private func encode(_ body: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            return try encoder.encode(body)
        } catch {
            throw MixtapeError.decoding
        }
    }
}

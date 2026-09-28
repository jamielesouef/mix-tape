//  JellyfinHTTPClient.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public struct JellyfinHTTPClient: Sendable {
    let session: URLSession
    let clientName: String
    let deviceName: String

    /// - Parameters:
    ///   - clientName: The `Client` field of the authorization header; the server's
    ///     dashboard lists sessions under it.
    ///   - deviceName: The `Device` field, shown beside the client name.
    public init(session: URLSession, clientName: String, deviceName: String) {
        self.session = session
        self.clientName = clientName
        self.deviceName = deviceName
    }

    public func get<T: Decodable & Sendable>(
        _ path: String,
        query: [URLQueryItem] = [],
        auth: AuthContext
    ) async throws -> T {
        let request = try makeRequest(
            method: "GET",
            path: path,
            query: query,
            auth: auth,
            body: nil
        )
        let data = try await perform(request, path: path)

        return try decode(T.self, from: data)
    }

    public func post<T: Decodable & Sendable>(
        _ path: String,
        body: some Encodable & Sendable,
        query: [URLQueryItem] = [],
        auth: AuthContext
    ) async throws -> T {
        let request = try makeRequest(
            method: "POST",
            path: path,
            query: query,
            auth: auth,
            body: encode(body)
        )
        let data = try await perform(request, path: path)

        return try decode(T.self, from: data)
    }

    public func post(
        _ path: String,
        body: some Encodable & Sendable,
        query: [URLQueryItem] = [],
        auth: AuthContext
    ) async throws {
        let request = try makeRequest(
            method: "POST",
            path: path,
            query: query,
            auth: auth,
            body: encode(body)
        )

        _ = try await perform(request, path: path)
    }

    // MARK: - Request assembly

    func authorizationHeader(for auth: AuthContext) -> String {
        let client = escaped(clientName)
        let device = escaped(deviceName)

        var fields = [
            "Client=\"\(client)\"",
            "Device=\"\(device)\"",
            "DeviceId=\"\(auth.deviceID)\"",
            "Version=\"\(auth.appVersion)\""
        ]

        if let token = auth.token {
            fields.append("Token=\"\(token)\"")
        }

        return "MediaBrowser " + fields.joined(separator: ", ")
    }

    /// Header values are quoted, so a quote or backslash inside one has to be escaped.
    private func escaped(_ value: String) -> String {
        value.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"")
    }

    private func makeRequest(
        method: String,
        path: String,
        query: [URLQueryItem],
        auth: AuthContext,
        body: Data?
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: auth.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        else {
            throw JellyfinError.transport(path)
        }

        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else {
            throw JellyfinError.transport(path)
        }

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
            throw JellyfinErrorMapper.map(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw JellyfinError.transport(path)
        }

        if let failure = JellyfinErrorMapper.map(status: http.statusCode, path: path) {
            throw failure
        }

        return data
    }

    // MARK: - JSON

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw JellyfinError.decoding
        }
    }

    private func encode(_ body: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        do {
            return try encoder.encode(body)
        } catch {
            throw JellyfinError.decoding
        }
    }
}

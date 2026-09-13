//  ValidateServerUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain

public nonisolated struct ValidateServerUseCase: Sendable {
    private let repository: any AuthRepositoryProtocol

    public init(repository: any AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(urlText: String) async throws -> ServerIdentity {
        let text = Self.normalised(urlText)
        guard text.isEmpty == false else { throw MixtapeError.serverUnreachable }
        if text.contains("://") {
            return try await identity(at: text)
        }
        do {
            return try await identity(at: "https://" + text)
        } catch {
            return try await identity(at: "http://" + text)
        }
    }

    private func identity(at text: String) async throws -> ServerIdentity {
        guard let url = URL(string: text), url.host() != nil else { throw MixtapeError.serverUnreachable }
        return try await repository.serverIdentity(at: url)
    }

    static func normalised(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}

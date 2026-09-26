// TEMPLATE — Repository implementation. Copy, rename, delete this header.
//
// Layer: Data/<Feature>/<Name>Repository.swift
//
// - `final class`, conforms to its own `*RepositoryProtocol` and `Sendable`.
//   Stateless: no `var`, no cache, no ambient global. The language it needs
//   arrives in `ExampleFeatureContext`, composed at the app's root.
// - Composes a transport and maps every DTO to its domain type with
//   `toDomain()`. It never returns a DTO.
// - NOT `@MainActor`. Never annotate a repository `@MainActor` to silence an
//   isolation error; that drags request, decode and mapping onto the main
//   thread, which is the bug the concurrency rules exist to prevent.

import Foundation

final class ExampleFeatureRepository: ExampleFeatureRepositoryProtocol, Sendable {
    // MARK: - Private

    private let transport: any ExampleFeatureHTTPTransportProtocol
    private let context: ExampleFeatureContext

    // MARK: - Init

    init(
        transport: any ExampleFeatureHTTPTransportProtocol,
        context: ExampleFeatureContext
    ) {
        self.transport = transport
        self.context = context
    }

    // MARK: - ExampleFeatureRepositoryProtocol

    func fetchItems() async throws(ExampleFeatureError) -> [ExampleFeatureItem] {
        let response = try await transport.fetchItems(language: context.languageCode)
        return response.data.map { $0.toDomain() }
    }
}

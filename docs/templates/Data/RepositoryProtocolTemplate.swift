// TEMPLATE — Repository protocol. Copy, rename, delete this header.
//
// Layer: Data/<Feature>/Protocol/<Name>RepositoryProtocol.swift
//
// - Suffix `*RepositoryProtocol`.
// - `Sendable`: a repository is stateless and crosses actor boundaries.
// - Typed throws so every call site gets a compiler-checked exhaustive
//   `catch`. No untyped `throws` at this boundary.
// - Returns domain types, never DTOs.
// - Narrow: only the operations this feature's service calls. Don't grow a
//   god-protocol.

protocol ExampleFeatureRepositoryProtocol: Sendable {
    func fetchItems() async throws(ExampleFeatureError) -> [ExampleFeatureItem]
}

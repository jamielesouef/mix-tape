// TEMPLATE — per-feature transport protocol. Copy, rename, delete this header.
//
// Layer: Data/<Feature>/Protocol/<Name>HTTPTransportProtocol.swift
//
// The seam between the repository and HTTP. Returns DTOs, not domain types;
// the repository maps. `Sendable` because the repository holds it and both
// cross isolation. Typed throws so the repository's `catch` is exhaustive.
// A test-target stub for this protocol lets a repository be tested without
// a `URLProtocol`.

protocol ExampleFeatureHTTPTransportProtocol: Sendable {
    func fetchItems(language: String) async throws(ExampleFeatureError) -> ExampleFeatureItemsResponseDTO
}

// TEMPLATE — Domain error enum. Copy, rename, delete this header.
//
// Layer: Domain/<Feature>/<Name>Error.swift
//
// - One minimal `Error` enum per feature. Not a catch-all `AppError`.
// - Conform to `APIError` (Data/Networking/APIErrorTemplate.swift) when this
//   error crosses the shared send/validate/decode path. That protocol needs
//   `.network`, `.server`, `.decoding`, `.encoding`, `.unauthorised`,
//   `.forbidden` and `.notFound` as cases. A feature-only error that never
//   touches HTTP doesn't conform.
// - A case names its OWN failure. `.itemUnavailable` exists because a
//   response can be well-formed and still not carry the thing the caller
//   asked for. That is not `.decoding`; throwing the nearest-fit case hides
//   what actually went wrong.
// - `Equatable` so tests can `#expect(error == .network)` and so `LoadState`
//   can be `Equatable`.
// - Used with typed throws at every boundary:
//   `func fetchItems() async throws(ExampleFeatureError) -> [ExampleFeatureItem]`

enum ExampleFeatureError: Error, Equatable, APIError {
    case network
    case server
    case decoding
    case encoding
    case unauthorised
    case forbidden
    case notFound
    case itemUnavailable
}

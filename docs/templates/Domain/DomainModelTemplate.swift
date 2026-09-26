// TEMPLATE — Domain model. Copy, rename, delete this header.
//
// Layer: Domain/<Feature>/<Name>.swift
//
// - Pure data. Computed reads that derive from stored properties are fine.
//   A method that calls a repository or service is not; that is the
//   service's job.
// - `struct`, value semantics. `Sendable` is inferred for a non-public value
//   type whose members are all Sendable, so it is not written here. Write it
//   only if the type becomes `public` across a module boundary, or needs
//   `@unchecked`.
// - No SwiftUI import. A SwiftUI-only value the view needs mapped from this
//   model is mapped in Presentation/, never here.
// - A DTO maps INTO this shape (see Data/DTOTemplate.swift). This type never
//   imports a DTO or knows about JSON.
// - Use the domain's own noun for the concept, consistently. Don't coin a
//   synonym because the presentation layer already drifted.

import Foundation

struct ExampleFeatureItem: Identifiable, Equatable {
    // MARK: - Stored

    let id: String
    let title: String
    let thumbnailURL: URL?
    let likeCount: Int
    let ownerID: Int

    // MARK: - Derived

    var hasThumbnail: Bool {
        thumbnailURL != nil
    }
}

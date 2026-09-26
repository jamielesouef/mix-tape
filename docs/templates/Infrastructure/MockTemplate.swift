// TEMPLATE — app-target mock. Copy, rename, delete this header.
//
// Layer: Infrastructure/Mocks/Mock<Name>Repository.swift
//
// - `Mock*` lives in the APP target, inside `#if DEBUG`, so previews can use
//   it and the composition root can substitute it under `#if TESTING`. It
//   never ships in a release build. Test-target doubles are `Stub*` and live
//   in the test target (unittests/).
// - It holds no mutable state, so it is a `struct`. A double that records
//   calls belongs in the test target as an `actor`.
// - Conforms to the real protocol and nothing more. Returns a fixed,
//   realistic fixture: long titles, a zero count, a missing image. Never
//   "Test Item".

import Foundation

#if DEBUG
    struct MockExampleFeatureRepository: ExampleFeatureRepositoryProtocol {
        // MARK: - Fixtures

        static let previewItems = [
            ExampleFeatureItem(
                id: "1",
                title: "Morning news",
                thumbnailURL: URL(string: "https://placecats.com/300/200"),
                likeCount: 1_234_567,
                ownerID: 42
            ),
            ExampleFeatureItem(
                id: "2",
                title: "A Very Long Title That Should Truncate At Some Point",
                thumbnailURL: nil,
                likeCount: 0,
                ownerID: 43
            )
        ]

        // MARK: - Input

        let items: [ExampleFeatureItem]

        // MARK: - Init

        init(items: [ExampleFeatureItem] = previewItems) {
            self.items = items
        }

        // MARK: - ExampleFeatureRepositoryProtocol

        func fetchItems() async throws(ExampleFeatureError) -> [ExampleFeatureItem] {
            items
        }
    }
#endif

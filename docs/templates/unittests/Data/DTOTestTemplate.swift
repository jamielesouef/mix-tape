// TEMPLATE — DTO decode and mapping test. Copy, rename, delete this header.
//
// Layer: <TestTarget>/Data/<Name>DTOTests.swift
//
// - Decodes the shared fixture (Fixtures/PayloadFixturesTemplate.swift) with
//   the PRODUCTION decoder, `APICoding.makeDecoder()`. A test-local decoder
//   can pass while the app's rejects the same payload.
// - Decode and `toDomain()` are tested in the same suite: from the reader's
//   point of view they are one round trip, wire JSON -> domain model.
// - Separate `@Test`s for the full decode, absent optionals, and order.
//   They are different behaviours.
// - `try #require(...)` to unwrap what the test needs to proceed. Never a
//   force-unwrap.

import Foundation
import Testing
@testable import ExampleApp

@Suite("ExampleFeatureItemDTO", .tags(.data))
struct ExampleFeatureItemDTOTests {
    // MARK: - Helpers

    private static func decodeFixture() throws -> ExampleFeatureItemsResponseDTO {
        try APICoding.makeDecoder().decode(
            ExampleFeatureItemsResponseDTO.self,
            from: Data(ExampleFeaturePayloadFixtures.items.utf8)
        )
    }

    // MARK: - Tests

    @Test("maps every field onto the domain model")
    func mapsEveryField() throws {
        let response = try Self.decodeFixture()
        let dto = try #require(response.data.first)

        let domain = dto.toDomain()

        #expect(domain.id == "a")
        #expect(domain.title == "Morning news")
        #expect(domain.likeCount == 12345)
        #expect(domain.thumbnailURL == URL(string: "https://example.com/thumb.jpg"))
        #expect(domain.ownerID == 42)
    }

    @Test("defaults genuinely optional fields when the wire omits them")
    func defaultsAbsentOptionals() throws {
        let response = try Self.decodeFixture()
        let dto = try #require(response.data.last)

        let domain = dto.toDomain()

        #expect(domain.title == "")
        #expect(domain.likeCount == 0)
        #expect(domain.thumbnailURL == nil)
        #expect(domain.hasThumbnail == false)
    }

    @Test("preserves the wire order of the list")
    func preservesOrder() throws {
        let response = try Self.decodeFixture()

        #expect(response.data.map(\.id) == ["a", "b"])
        #expect(response.message == "OK")
    }
}

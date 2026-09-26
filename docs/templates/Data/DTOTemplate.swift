// TEMPLATE — DTO (wire-format boundary type). Copy, rename, delete this header.
//
// Layer: Data/<Feature>/DTO/<Name>DTO.swift
//
// - A DTO models what the wire actually sends, not what you wish it sent.
//   Every field the API might omit is `Optional`. Absence is defaulted in
//   `toDomain()` and nowhere else.
// - `Decodable` for a response, `Encodable` for a request body. `Sendable`
//   is inferred; don't write it.
// - Nested payload shapes are nested DTO structs, never flattened by hand.
// - `CodingKeys` lists ONLY the keys the shared decoder can't derive. The
//   decoder converts snake_case to camelCase (Data/Networking/APICodingTemplate.swift),
//   so `like_count` -> `likeCount` needs nothing. `owner_id` becomes
//   `ownerId`, and the Swift name is `ownerID` (acronyms stay uppercase),
//   so that one key is named. If no key needs it, there is no `CodingKeys`.
// - `toDomain()` maps DTO -> domain model in an extension in the same file.
//   The domain type never sees JSON.

import Foundation

struct ExampleFeatureItemDTO: Decodable {
    // MARK: - Nested

    struct ThumbnailDTO: Decodable {
        let src: String?
    }

    // MARK: - Fields

    let id: String
    let title: String?
    let likeCount: Int?
    let thumbnail: ThumbnailDTO?
    let ownerID: Int

    // MARK: - Coding keys

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case likeCount
        case thumbnail
        case ownerID = "ownerId"
    }
}

// MARK: - Domain mapping

extension ExampleFeatureItemDTO {
    func toDomain() -> ExampleFeatureItem {
        ExampleFeatureItem(
            id: id,
            title: title ?? "",
            thumbnailURL: thumbnail?.src.flatMap { URL(string: $0) },
            likeCount: likeCount ?? 0,
            ownerID: ownerID
        )
    }
}

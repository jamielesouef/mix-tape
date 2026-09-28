//  ItemsResultDTO.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct ItemsResultDTO: Decodable, Sendable {
    public let items: [BaseItemDTO]?
    public let totalRecordCount: Int?
    public let startIndex: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
        case startIndex = "StartIndex"
    }
}

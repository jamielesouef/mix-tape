//  BaseItemDTO.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct BaseItemDTO: Decodable, Sendable {
    public let id: String
    public let name: String?
    public let type: String?
    public let collectionType: String?
    public let overview: String?
    public let productionYear: Int?
    public let runTimeTicks: Int64?
    public let indexNumber: Int?
    public let parentIndexNumber: Int?
    public let albumArtist: String?
    public let albumId: String?
    public let albumPrimaryImageTag: String?
    public let container: String?
    public let imageTags: [String: String]?
    public let backdropImageTags: [String]?
    public let genres: [String]?
    public let userData: UserItemDataDTO?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case collectionType = "CollectionType"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case runTimeTicks = "RunTimeTicks"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case albumArtist = "AlbumArtist"
        case albumId = "AlbumId"
        case albumPrimaryImageTag = "AlbumPrimaryImageTag"
        case container = "Container"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case genres = "Genres"
        case userData = "UserData"
    }
}

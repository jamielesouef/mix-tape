//  BaseItemDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// `BaseItemDto`, the shape every library call returns. Image fields per decision 25.
nonisolated struct BaseItemDTO: Decodable {
    let id: String
    let name: String?
    let type: String?
    let collectionType: String?
    let overview: String?
    let productionYear: Int?
    let runTimeTicks: Int64?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let seriesName: String?
    let albumArtist: String?
    let albumId: String?
    let albumPrimaryImageTag: String?
    let imageTags: [String: String]?
    let backdropImageTags: [String]?
    let userData: UserItemDataDTO?

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
        case seriesName = "SeriesName"
        case albumArtist = "AlbumArtist"
        case albumId = "AlbumId"
        case albumPrimaryImageTag = "AlbumPrimaryImageTag"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case userData = "UserData"
    }
}

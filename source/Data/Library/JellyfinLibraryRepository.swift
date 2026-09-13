//  JellyfinLibraryRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

nonisolated struct JellyfinLibraryRepository: LibraryRepositoryProtocol {
    private let client: JellyfinHTTPClient
    private let appVersion: String

    private static let listFields = "Overview,PrimaryImageAspectRatio"

    init(client: JellyfinHTTPClient, appVersion: String) {
        self.client = client
        self.appVersion = appVersion
    }

    func libraries(session: UserSession) async throws -> [Library] {
        let dto: ItemsResultDTO = try await client.get("/UserViews", query: [user(session)], auth: context(session))
        return (dto.items ?? []).map(LibraryMapper.library)
    }

    func items(in libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem> {
        let dto: ItemsResultDTO = try await client.get(
            "/Items",
            query: [
                user(session),
                URLQueryItem(name: "parentId", value: libraryID),
                URLQueryItem(name: "includeItemTypes", value: Self.itemType(kind)),
                URLQueryItem(name: "recursive", value: "true"),
                URLQueryItem(name: "sortBy", value: "SortName"),
                URLQueryItem(name: "sortOrder", value: "Ascending"),
                URLQueryItem(name: "fields", value: Self.listFields),
                URLQueryItem(name: "imageTypeLimit", value: "1"),
                URLQueryItem(name: "enableImageTypes", value: "Primary,Backdrop"),
                URLQueryItem(name: "startIndex", value: String(page.startIndex)),
                URLQueryItem(name: "limit", value: String(page.limit)),
            ],
            auth: context(session),
        )
        return LibraryMapper.page(from: dto, requested: page)
    }

    func item(id: String, session: UserSession) async throws -> MediaItem {
        let dto: BaseItemDTO = try await client.get(
            "/Items/\(id)", query: [user(session), URLQueryItem(name: "fields", value: "Overview,MediaSources")], auth: context(session),
        )
        return try LibraryMapper.detail(from: dto)
    }

    func tracks(albumID: String, session: UserSession) async throws -> [MediaItem] {
        let dto: ItemsResultDTO = try await client.get(
            "/Items",
            query: [
                user(session),
                URLQueryItem(name: "parentId", value: albumID),
                URLQueryItem(name: "includeItemTypes", value: "Audio"),
                URLQueryItem(name: "sortBy", value: "ParentIndexNumber,IndexNumber,SortName"),
            ],
            auth: context(session),
        )
        return LibraryMapper.items(from: dto)
    }

    private static func itemType(_ kind: MediaKind) -> String {
        switch kind {
        case .musicAlbum: "MusicAlbum"
        case .audio: "Audio"
        }
    }

    private func user(_ session: UserSession) -> URLQueryItem {
        URLQueryItem(name: "userId", value: session.userID)
    }

    private func context(_ session: UserSession) -> AuthContext {
        AuthContext(baseURL: session.serverURL, deviceID: session.deviceID, appVersion: appVersion, token: session.accessToken)
    }
}

//  JellyfinLibraryRepository.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure
import MixtapeUseCase

/// Engineering doc §8 "Library", corrected by decisions 6, 26, 27 and 30. Stateless; `userId`
/// is sent on every call and the session token rides in the `Authorization` header.
public nonisolated struct JellyfinLibraryRepository: LibraryRepositoryProtocol {
    private let client: JellyfinHTTPClient
    private let appVersion: String

    private static let listFields = "Overview,PrimaryImageAspectRatio"

    public init(client: JellyfinHTTPClient, appVersion: String) {
        self.client = client
        self.appVersion = appVersion
    }

    public func libraries(session: UserSession) async throws -> [Library] {
        let dto: ItemsResultDTO = try await client.get("/UserViews", query: [user(session)], auth: context(session))
        return (dto.items ?? []).map(LibraryMapper.library)
    }

    public func items(in libraryID: String, kind: MediaKind, page: PageRequest, session: UserSession) async throws -> Page<MediaItem> {
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

    /// `fields=` is accepted by the server although the spec under-declares it (decision 26).
    public func item(id: String, session: UserSession) async throws -> MediaItem {
        let dto: BaseItemDTO = try await client.get(
            "/Items/\(id)", query: [user(session), URLQueryItem(name: "fields", value: "Overview,MediaSources")], auth: context(session),
        )
        return try LibraryMapper.detail(from: dto)
    }

    public func seasons(seriesID: String, session: UserSession) async throws -> [MediaItem] {
        let dto: ItemsResultDTO = try await client.get("/Shows/\(seriesID)/Seasons", query: [user(session)], auth: context(session))
        return LibraryMapper.items(from: dto)
    }

    /// Sorted explicitly (decision 27); AC11 needs the order, not just a legal sort key.
    public func episodes(seriesID: String, seasonID: String, session: UserSession) async throws -> [MediaItem] {
        let dto: ItemsResultDTO = try await client.get(
            "/Shows/\(seriesID)/Episodes",
            query: [
                user(session),
                URLQueryItem(name: "seasonId", value: seasonID),
                URLQueryItem(name: "sortBy", value: "ParentIndexNumber,IndexNumber"),
                URLQueryItem(name: "fields", value: "Overview"),
            ],
            auth: context(session),
        )
        return LibraryMapper.items(from: dto)
    }

    public func tracks(albumID: String, session: UserSession) async throws -> [MediaItem] {
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

    /// `/UserItems/Resume`, not `/Items/Resume` (decision 6).
    public func continueWatching(session: UserSession) async throws -> [MediaItem] {
        let dto: ItemsResultDTO = try await client.get(
            "/UserItems/Resume",
            query: [
                user(session),
                URLQueryItem(name: "limit", value: "12"),
                URLQueryItem(name: "mediaTypes", value: "Video"),
                URLQueryItem(name: "fields", value: "Overview"),
            ],
            auth: context(session),
        )
        return LibraryMapper.items(from: dto)
    }

    private static func itemType(_ kind: MediaKind) -> String {
        switch kind {
        case .movie: "Movie"
        case .series: "Series"
        case .season: "Season"
        case .episode: "Episode"
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

//  LibraryMapper.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

nonisolated enum LibraryMapper {
    static func library(from dto: BaseItemDTO) -> Library {
        let kind: LibraryKind = switch dto.collectionType {
        case "movies": .movies
        case "tvshows": .tvShows
        case "music": .music
        default: .unsupported
        }
        return Library(id: dto.id, name: dto.name ?? "", kind: kind, imageTag: dto.imageTags?["Primary"])
    }

    /// Items whose `Type` is outside `MediaKind` are dropped rather than failing the list.
    static func items(from dto: ItemsResultDTO) -> [MediaItem] {
        (dto.items ?? []).compactMap(mediaItem)
    }

    static func page(from dto: ItemsResultDTO, requested: PageRequest) -> Page<MediaItem> {
        let items = items(from: dto)
        return Page(items: items, totalCount: dto.totalRecordCount ?? items.count, startIndex: dto.startIndex ?? requested.startIndex)
    }

    /// A single item of an unknown type is a decoding failure: there is no list to drop it from.
    static func detail(from dto: BaseItemDTO) throws -> MediaItem {
        guard let item = mediaItem(from: dto) else { throw MixtapeError.decoding }
        return item
    }

    static func mediaItem(from dto: BaseItemDTO) -> MediaItem? {
        guard let kind = kind(dto.type) else { return nil }
        let position = dto.userData?.playbackPositionTicks.map { Duration(ticks: $0) } ?? .zero
        return MediaItem(
            id: dto.id,
            name: dto.name ?? "",
            kind: kind,
            overview: dto.overview,
            productionYear: dto.productionYear,
            runtime: dto.runTimeTicks.map { Duration(ticks: $0) },
            indexNumber: dto.indexNumber,
            parentIndexNumber: dto.parentIndexNumber,
            seriesName: dto.seriesName,
            albumArtist: dto.albumArtist,
            primaryImageTag: dto.imageTags?["Primary"],
            backdropImageTag: dto.backdropImageTags?.first,
            parentPrimaryImageTag: dto.albumPrimaryImageTag,
            albumID: dto.albumId,
            playback: PlaybackState(position: position, isWatched: dto.userData?.played ?? false),
        )
    }

    private static func kind(_ type: String?) -> MediaKind? {
        switch type {
        case "Movie": .movie
        case "Series": .series
        case "Season": .season
        case "Episode": .episode
        case "MusicAlbum": .musicAlbum
        case "Audio": .audio
        default: nil
        }
    }
}

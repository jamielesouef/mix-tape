//  LibraryService+Placeholder.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeUseCase

public extension LibraryService {
    /// `@Entry` default. Never used by a running app — the composition root always injects one.
    /// Debug builds use the preview mock; release builds, which carry no `Mock*` type (slice 013),
    /// build the same service over the inert `Placeholder*` collaborators.
    static let placeholder: LibraryService = {
        #if DEBUG
            return MockLibraryService.idle()
        #else
            let repository = PlaceholderLibraryRepository()
            return LibraryService(
                fetchLibraries: FetchLibrariesUseCase(repository: repository),
                fetchLibraryItems: FetchLibraryItemsUseCase(repository: repository),
                fetchItemDetail: FetchItemDetailUseCase(repository: repository),
                fetchAlbumTracks: FetchAlbumTracksUseCase(repository: repository),
                fetchContinueWatching: FetchContinueWatchingUseCase(repository: repository),
                sessionService: .placeholder,
            )
        #endif
    }()
}

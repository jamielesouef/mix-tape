//  LibraryService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

extension LibraryService {
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
                sessionService: .placeholder,
            )
        #endif
    }()
}

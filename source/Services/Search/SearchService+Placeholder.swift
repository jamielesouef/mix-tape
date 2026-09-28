//  SearchService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

extension SearchService {
    static let placeholder: SearchService = {
        #if DEBUG
            return MockSearchService.idle()
        #else
            return SearchService(
                search: SearchLibraryUseCase(repository: MockServerSearchRepository()),
                sessionService: .placeholder,
                downloadsService: .placeholder,
                networkMonitor: NetworkPathMonitor()
            )
        #endif
    }()
}

//  MockMedia.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG

    enum MockMedia {
        static let libraries = MockLibraryRepository.sampleLibraries
        static let albums = MockLibraryRepository.sampleAlbums
        static let tracks = MockLibraryRepository.sampleTracks
    }
#endif

//  MockMedia.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG

    public enum MockMedia {
        public static let libraries = MockLibraryRepository.sampleLibraries
        public static let movies = MockLibraryRepository.sampleMovies
        public static let series = MockLibraryRepository.sampleSeries
        public static let seasons = MockLibraryRepository.sampleSeasons
        public static let episodes = MockLibraryRepository.sampleEpisodes
        public static let albums = MockLibraryRepository.sampleAlbums
        public static let tracks = MockLibraryRepository.sampleTracks
    }
#endif

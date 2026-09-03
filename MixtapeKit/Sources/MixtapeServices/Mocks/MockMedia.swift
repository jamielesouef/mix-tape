//  MockMedia.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeUseCase

/// The mock repository's sample data, re-exported so Presentation previews can reach it without
/// importing `MixtapeUseCase` (engineering doc §3).
public enum MockMedia {
    public static let libraries = MockLibraryRepository.sampleLibraries
    public static let movies = MockLibraryRepository.sampleMovies
    public static let series = MockLibraryRepository.sampleSeries
    public static let seasons = MockLibraryRepository.sampleSeasons
    public static let episodes = MockLibraryRepository.sampleEpisodes
    public static let albums = MockLibraryRepository.sampleAlbums
    public static let tracks = MockLibraryRepository.sampleTracks
}

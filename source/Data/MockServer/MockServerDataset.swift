//  MockServerDataset.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

/// The fixed catalogue every `MockServer*` repository reads from — one library, five
/// artists, five albums each, six tracks per album. Standing in for a real Jellyfin server
/// while the seam (`*RepositoryProtocol`) is exercised end to end.
enum MockServerDataset {
    static let libraryID = "mock-lib-music"
    static let library = Library(id: libraryID, name: "Music", kind: .music, imageTag: "cover")

    static let albums: [MediaItem] = makeAlbums()
    static let allTracks: [MediaItem] = albums.flatMap { tracksByAlbumID[$0.id] ?? [] }

    static let tracksByAlbumID: [String: [MediaItem]] = makeTracks()

    static func album(id: String) -> MediaItem? {
        albums.first { $0.id == id }
    }

    static func tracks(albumID: String) -> [MediaItem] {
        tracksByAlbumID[albumID] ?? []
    }

    // MARK: - Private seed data

    private struct AlbumSeed {
        let title: String
        let artist: String
        let year: Int
        let genre: String
    }

    private static let seeds: [AlbumSeed] = [
        // Paper Cranes — Indie
        AlbumSeed(title: "Paper Lanterns", artist: "Paper Cranes", year: 2018, genre: "Indie"),
        AlbumSeed(title: "Quiet Static", artist: "Paper Cranes", year: 2020, genre: "Indie"),
        AlbumSeed(title: "Faded Postcards", artist: "Paper Cranes", year: 2021, genre: "Indie"),
        AlbumSeed(title: "Amber Rooms", artist: "Paper Cranes", year: 2023, genre: "Indie"),
        AlbumSeed(title: "Slow Weather", artist: "Paper Cranes", year: 2025, genre: "Indie"),
        // Static Bloom — Electronic
        AlbumSeed(title: "Neon Tide", artist: "Static Bloom", year: 2017, genre: "Electronic"),
        AlbumSeed(title: "Glass Skyline", artist: "Static Bloom", year: 2019, genre: "Electronic"),
        AlbumSeed(title: "Wire Garden", artist: "Static Bloom", year: 2021, genre: "Electronic"),
        AlbumSeed(title: "Midnight Signal", artist: "Static Bloom", year: 2023, genre: "Electronic"),
        AlbumSeed(title: "Second Horizon", artist: "Static Bloom", year: 2025, genre: "Electronic"),
        // Harbor Quartet — Jazz
        AlbumSeed(title: "Late Harbor", artist: "Harbor Quartet", year: 2016, genre: "Jazz"),
        AlbumSeed(title: "Blue Compass", artist: "Harbor Quartet", year: 2019, genre: "Jazz"),
        AlbumSeed(title: "Low Tide Sessions", artist: "Harbor Quartet", year: 2020, genre: "Jazz"),
        AlbumSeed(title: "Velvet Current", artist: "Harbor Quartet", year: 2022, genre: "Jazz"),
        AlbumSeed(title: "Winter Lantern", artist: "Harbor Quartet", year: 2024, genre: "Jazz"),
        // Iron Horizon — Rock
        AlbumSeed(title: "Hollow Wire", artist: "Iron Horizon", year: 2015, genre: "Rock"),
        AlbumSeed(title: "Broken Static", artist: "Iron Horizon", year: 2018, genre: "Rock"),
        AlbumSeed(title: "Silver Ember", artist: "Iron Horizon", year: 2020, genre: "Rock"),
        AlbumSeed(title: "Distant Engines", artist: "Iron Horizon", year: 2022, genre: "Rock"),
        AlbumSeed(title: "The Long Descent", artist: "Iron Horizon", year: 2025, genre: "Rock"),
        // Echo District — Hip-Hop
        AlbumSeed(title: "Echo District", artist: "Echo District", year: 2017, genre: "Hip-Hop"),
        AlbumSeed(title: "Concrete Bloom", artist: "Echo District", year: 2019, genre: "Hip-Hop"),
        AlbumSeed(title: "Night Ledger", artist: "Echo District", year: 2021, genre: "Hip-Hop"),
        AlbumSeed(title: "Paper Crown", artist: "Echo District", year: 2023, genre: "Hip-Hop"),
        AlbumSeed(title: "Second Skyline", artist: "Echo District", year: 2025, genre: "Hip-Hop")
    ]

    private static let titleAdjectives = [
        "Neon",
        "Velvet",
        "Silver",
        "Broken",
        "Golden",
        "Quiet",
        "Electric",
        "Faded",
        "Wild",
        "Hollow",
        "Amber",
        "Distant",
        "Paper",
        "Midnight",
        "Static",
        "Second"
    ]

    private static let titleNouns = [
        "Skyline",
        "Echo",
        "Harbor",
        "Static",
        "Garden",
        "Signal",
        "Horizon",
        "Wire",
        "Bloom",
        "Tide",
        "Ember",
        "Compass",
        "Glass",
        "Lantern",
        "Current",
        "Weather"
    ]

    private static let tracksPerAlbum = 6

    private static func makeAlbums() -> [MediaItem] {
        seeds.enumerated().map { index, seed in
            MediaItem(
                id: "mock-album-\(index)",
                name: seed.title,
                kind: .musicAlbum,
                overview: nil,
                productionYear: seed.year,
                runtime: nil,
                indexNumber: nil,
                parentIndexNumber: nil,
                albumArtist: seed.artist,
                primaryImageTag: "cover",
                backdropImageTag: nil,
                parentPrimaryImageTag: nil,
                genre: seed.genre,
                playCount: (index * 17 + 5) % 40,
                playback: PlaybackState(position: .zero)
            )
        }
    }

    private static func makeTracks() -> [String: [MediaItem]] {
        var result: [String: [MediaItem]] = [:]

        for (albumIndex, seed) in seeds.enumerated() {
            let albumID = "mock-album-\(albumIndex)"

            result[albumID] = (0 ..< tracksPerAlbum).map { trackIndex in
                trackItem(
                    albumIndex: albumIndex,
                    albumID: albumID,
                    trackIndex: trackIndex,
                    seed: seed
                )
            }
        }

        return result
    }

    private static func trackItem(
        albumIndex: Int,
        albumID: String,
        trackIndex: Int,
        seed: AlbumSeed
    ) -> MediaItem {
        let adjective = titleAdjectives[(albumIndex * 3 + trackIndex) % titleAdjectives.count]
        let noun = titleNouns[(albumIndex * 5 + trackIndex * 7) % titleNouns.count]
        let seconds = 180 + ((trackIndex * 23 + albumIndex * 11) % 80)

        return MediaItem(
            id: "\(albumID)-track-\(trackIndex)",
            name: "\(adjective) \(noun)",
            kind: .audio,
            overview: nil,
            productionYear: seed.year,
            runtime: .seconds(seconds),
            indexNumber: trackIndex + 1,
            parentIndexNumber: 1,
            albumArtist: seed.artist,
            primaryImageTag: nil,
            backdropImageTag: nil,
            parentPrimaryImageTag: "cover",
            albumID: albumID,
            container: "mp3",
            genre: seed.genre,
            playCount: 0,
            playback: PlaybackState(position: .zero)
        )
    }
}

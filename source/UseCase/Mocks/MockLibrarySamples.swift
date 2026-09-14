//  MockLibrarySamples.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

#if DEBUG

    /// The fixed library, album and track data every mock, preview and test draws on.
    enum MockLibrarySamples {
        static let libraries = [
            Library(id: "lib-music", name: "Music", kind: .music, imageTag: "t-music"),
            Library(id: "lib-books", name: "Books", kind: .unsupported, imageTag: nil)
        ]

        static let albums = [
            item(
                id: "album-1",
                name: "Even In Arcadia",
                kind: .musicAlbum,
                year: 2025,
                albumArtist: "Sleep Token",
                primary: "a1"
            ),
            item(
                id: "album-2",
                name: "Sundowning",
                kind: .musicAlbum,
                year: 2019,
                albumArtist: "Sleep Token",
                primary: "a2"
            ),
            item(
                id: "album-3",
                name: "This Place Will Become Your Tomb",
                kind: .musicAlbum,
                year: 2021,
                albumArtist: "Sleep Token",
                primary: "a3"
            ),
            item(
                id: "album-4",
                name: "Take Me Back To Eden",
                kind: .musicAlbum,
                year: 2023,
                albumArtist: "Sleep Token",
                primary: "a4"
            ),
            item(
                id: "album-5",
                name: "King Of Terrors",
                kind: .musicAlbum,
                year: 2025,
                albumArtist: "President",
                primary: "a5"
            )
        ]

        static let tracks = [
            item(
                id: "track-1",
                name: "Look To Windward",
                kind: .audio,
                runtime: .seconds(380),
                indexNumber: 1,
                parentIndexNumber: 1,
                albumArtist: "Sleep Token",
                parentPrimary: "a1",
                albumID: "album-1"
            ),
            item(
                id: "track-2",
                name: "Emergence",
                kind: .audio,
                runtime: .seconds(305),
                indexNumber: 2,
                parentIndexNumber: 1,
                albumArtist: "Sleep Token",
                parentPrimary: "a1",
                albumID: "album-1"
            )
        ]

        // MARK: - Private

        private static func item(
            id: String,
            name: String,
            kind: MediaKind,
            year: Int? = nil,
            runtime: Duration? = nil,
            overview: String? = nil,
            indexNumber: Int? = nil,
            parentIndexNumber: Int? = nil,
            albumArtist: String? = nil,
            primary: String? = nil,
            backdrop: String? = nil,
            parentPrimary: String? = nil,
            albumID: String? = nil,
            position: Duration = .zero
        ) -> MediaItem {
            MediaItem(
                id: id,
                name: name,
                kind: kind,
                overview: overview,
                productionYear: year,
                runtime: runtime,
                indexNumber: indexNumber,
                parentIndexNumber: parentIndexNumber,
                albumArtist: albumArtist,
                primaryImageTag: primary,
                backdropImageTag: backdrop,
                parentPrimaryImageTag: parentPrimary,
                albumID: albumID,
                playback: PlaybackState(position: position)
            )
        }
    }
#endif

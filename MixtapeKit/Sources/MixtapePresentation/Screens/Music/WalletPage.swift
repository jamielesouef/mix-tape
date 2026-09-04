//  WalletPage.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// One page of the wallet: a fixed `columns × columns` block of sleeves (engineering doc §9.1,
    /// decision 20). Fixed, not adaptive — slots past the last album stay visible as empty sleeves.
    struct WalletPage: View {
        let albums: [MediaItem]
        let columns: Int
        let pulsingAlbumID: String?
        let namespace: Namespace.ID
        let select: (MediaItem) -> Void

        var body: some View {
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                ForEach(0 ..< columns, id: \.self) { row in
                    GridRow {
                        ForEach(0 ..< columns, id: \.self) { column in
                            let index = row * columns + column
                            if albums.indices.contains(index) {
                                Button { select(albums[index]) } label: {
                                    AlbumSleeve(album: albums[index], isPulsing: pulsingAlbumID == albums[index].id)
                                }
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: albums[index].id, in: namespace)
                                .accessibilityIdentifier(WalletIdentifiers.sleeve(albums[index].id))
                            } else {
                                AlbumSleeve(album: nil)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    #if DEBUG
        #Preview("loaded") {
            @Previewable @Namespace var namespace
            WalletPage(albums: MockMedia.albums, columns: 2, pulsingAlbumID: MockMedia.albums[0].id, namespace: namespace) { _ in }
                .environment(\.imageService, MockImageService.make())
        }

        #Preview("empty") {
            @Previewable @Namespace var namespace
            WalletPage(albums: [], columns: 3, pulsingAlbumID: nil, namespace: namespace) { _ in }
        }

        #Preview("failure") {
            @Previewable @Namespace var namespace
            WalletPage(albums: Array(MockMedia.albums.prefix(1)), columns: 2, pulsingAlbumID: nil, namespace: namespace) { _ in }
                .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
        }
    #endif
#endif

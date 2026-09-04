//  PosterGrid.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// iOS poster grid: 2-up compact / 4-up regular, paged by asking for more as the last cell appears.
    struct PosterGrid: View {
        @Environment(\.horizontalSizeClass) private var sizeClass
        let items: [MediaItem]
        let loadMore: () async -> Void

        var body: some View {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: sizeClass == .regular ? 4 : 2), spacing: 20) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            PosterCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(PosterGridIdentifiers.cell(item.id))
                        .task {
                            if item.id == items.last?.id {
                                await loadMore()
                            }
                        }
                    }
                }
                .padding()
            }
            .accessibilityIdentifier(PosterGridIdentifiers.grid)
        }
    }

    #if DEBUG
        #Preview("loaded") {
            NavigationStack {
                PosterGrid(items: MockMedia.movies) {}
            }
            .environment(\.imageService, MockImageService.make())
        }

        #Preview("empty") {
            NavigationStack {
                PosterGrid(items: []) {}
            }
        }

        #Preview("failure") {
            NavigationStack {
                PosterGrid(items: [MockMedia.series]) {}
            }
            .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
        }
    #endif
#endif

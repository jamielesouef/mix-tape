//  PosterGrid+tvOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// tvOS poster grid: a plain 6-up focus grid. Slice 011 replaces this with the shelf chrome.
    struct PosterGrid: View {
        let items: [MediaItem]
        let loadMore: () async -> Void

        var body: some View {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40, alignment: .top), count: 6), spacing: 48) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            PosterCard(item: item)
                        }
                        .buttonStyle(.card)
                        .accessibilityIdentifier(PosterGridIdentifiers.cell(item.id))
                        .task {
                            if item.id == items.last?.id {
                                await loadMore()
                            }
                        }
                    }
                }
                .padding(60)
            }
            .accessibilityIdentifier(PosterGridIdentifiers.grid)
        }
    }

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

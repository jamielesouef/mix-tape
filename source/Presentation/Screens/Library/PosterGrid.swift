//  PosterGrid.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct PosterGrid: View {
    @Environment(\.horizontalSizeClass) private var sizeClass: UserInterfaceSizeClass?
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

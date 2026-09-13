//  PosterShelf.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    struct PosterShelf: View {
        let title: String
        let items: [MediaItem]
        let loadMore: () async -> Void

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(title)
                        .font(.title.bold())
                        .accessibilityIdentifier(PosterShelfIdentifiers.titleLabel)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40, alignment: .top), count: 5), spacing: 48) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                PosterCard(item: item)
                            }
                            .buttonStyle(.card)
                            .accessibilityIdentifier(PosterShelfIdentifiers.cell(item.id))
                            .task {
                                if item.id == items.last?.id {
                                    await loadMore()
                                }
                            }
                        }
                    }
                }
                .padding(60)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(PosterShelfIdentifiers.shelf)
        }
    }

    #if DEBUG
        #Preview("loaded") {
            NavigationStack {
                PosterShelf(title: "Movies", items: MockMedia.movies) {}
            }
            .environment(\.imageService, MockImageService.make())
        }

        #Preview("empty") {
            NavigationStack {
                PosterShelf(title: "Movies", items: []) {}
            }
        }

        #Preview("failure") {
            NavigationStack {
                PosterShelf(title: "Shows", items: [MockMedia.series]) {}
            }
            .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
        }
    #endif
#endif

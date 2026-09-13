//  HomeScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

public struct HomeScreen: View {
    @Environment(\.libraryService) private var libraryService

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                switch libraryService.continueWatching {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                case let .failed(error):
                    RetryView(error: error) { await libraryService.loadHome() }
                case let .loaded(items) where items.isEmpty:
                    ContentUnavailableView("Nothing to continue", systemImage: "play.rectangle", description: Text("Start watching something and it will show up here."))
                        .accessibilityIdentifier(HomeIdentifiers.emptyLabel)
                case let .loaded(items):
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Continue Watching")
                            .font(.title2.bold())
                            .padding(.horizontal)
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: 16) {
                                ForEach(items) { item in
                                    NavigationLink(value: item) {
                                        ContinueWatchingCard(item: item)
                                    }
                                    .platformCardButtonStyle()
                                    .accessibilityIdentifier(HomeIdentifiers.card(item.id))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .accessibilityIdentifier(HomeIdentifiers.continueWatchingRow)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: MediaItem.self) { item in
                MediaItemDestination(item: item)
            }
            .task {
                if case .idle = libraryService.continueWatching {
                    await libraryService.loadHome()
                }
            }
        }
    }
}

#if DEBUG
    #Preview("loaded") {
        HomeScreen().environment(\.libraryService, MockLibraryService.loaded())
    }

    #Preview("empty") {
        HomeScreen().environment(\.libraryService, MockLibraryService.empty())
    }

    #Preview("failure") {
        HomeScreen().environment(\.libraryService, MockLibraryService.failed())
    }
#endif

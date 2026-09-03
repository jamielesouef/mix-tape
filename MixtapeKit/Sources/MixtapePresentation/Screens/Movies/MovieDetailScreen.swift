//  MovieDetailScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// Backdrop, title, year, runtime, overview, Play / Resume. The buttons render and do nothing
/// until slice 006 wires the video player. Also used for episodes pushed from Continue Watching.
public struct MovieDetailScreen: View {
    @Environment(\.libraryService) private var libraryService
    let item: MediaItem

    public init(item: MediaItem) {
        self.item = item
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RemoteImage(source: .item(current, current.backdropImageTag == nil ? .primary : .backdrop), maxHeight: 720, placeholder: "film")
                    .aspectRatio(16 / 9, contentMode: .fit)
                VStack(alignment: .leading, spacing: 12) {
                    Text(current.displayTitle)
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier(MovieDetailIdentifiers.titleLabel)
                    Text(metadata)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        // Wired to `VideoPlaybackService` in slice 006.
                        Button("Play", systemImage: "play.fill") {}
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(MovieDetailIdentifiers.playButton)
                        if current.playback.hasResumePoint {
                            Button("Resume", systemImage: "playpause.fill") {}
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier(MovieDetailIdentifiers.resumeButton)
                        }
                    }
                    if let fraction = current.progressFraction {
                        ProgressView(value: fraction)
                            .tint(.accentColor)
                    }
                    if let overview = current.overview, overview.isEmpty == false {
                        Text(overview)
                            .font(.body)
                            .accessibilityIdentifier(MovieDetailIdentifiers.overviewLabel)
                    }
                    if case let .failed(error) = libraryService.details[item.id] {
                        Text(error.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .glassChrome()
                .padding(.horizontal)
            }
        }
        .navigationTitle(current.name)
        .task { await libraryService.loadDetail(id: item.id) }
    }

    /// The freshly fetched item when it has arrived, else the one this screen was pushed with.
    private var current: MediaItem {
        if case let .loaded(detail) = libraryService.details[item.id] {
            return detail
        }
        return item
    }

    private var metadata: String {
        var parts: [String] = []
        if let seriesName = current.seriesName {
            parts.append(seriesName)
        }
        if let year = current.productionYear {
            parts.append(String(year))
        }
        if let runtime = current.runtime {
            parts.append(runtime.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
        }
        if current.playback.isWatched {
            parts.append("Watched")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview("loaded") {
    NavigationStack {
        MovieDetailScreen(item: MockMedia.movies[1])
    }
    .environment(\.libraryService, MockLibraryService.loaded())
}

#Preview("empty") {
    NavigationStack {
        MovieDetailScreen(item: MockMedia.movies[0])
    }
    .environment(\.libraryService, MockLibraryService.empty())
}

#Preview("failure") {
    NavigationStack {
        MovieDetailScreen(item: MockMedia.movies[1])
    }
    .environment(\.libraryService, MockLibraryService.failed())
}

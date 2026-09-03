//  MovieDetailScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// Backdrop, title, year, runtime, overview, Play / Resume. Play starts from the beginning and
/// Resume from the server's position; both present `VideoPlayerScreen` as a full-screen cover.
/// Also used for episodes pushed from Continue Watching.
public struct MovieDetailScreen: View {
    @Environment(\.libraryService) private var libraryService
    @Environment(\.videoPlaybackService) private var videoPlaybackService
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
                        Button("Play", systemImage: "play.fill") { play(from: .zero) }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(MovieDetailIdentifiers.playButton)
                        if current.playback.hasResumePoint {
                            Button("Resume", systemImage: "playpause.fill") { play(from: current.playback.position) }
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
        .fullScreenCover(isPresented: isPlayerPresented) {
            VideoPlayerScreen()
        }
    }

    private var isPlayerPresented: Binding<Bool> {
        Binding(
            get: { videoPlaybackService.isActive && videoPlaybackService.item?.id == item.id },
            set: { presented in
                if presented == false {
                    // On return from the player, reload so the new resume point shows as Resume (slice 008).
                    Task {
                        await videoPlaybackService.stop()
                        await libraryService.loadDetail(id: item.id)
                    }
                }
            },
        )
    }

    private func play(from position: Duration) {
        let target = current
        Task { await videoPlaybackService.play(item: target, startAt: position) }
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

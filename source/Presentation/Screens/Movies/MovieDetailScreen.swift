//  MovieDetailScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import SwiftUI

public struct MovieDetailScreen: View {
    @Environment(\.libraryService) private var libraryService: LibraryService
    @Environment(\.videoPlaybackService) private var videoPlaybackService: VideoPlaybackService
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
                    Text(current.detailMetadata)
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

    private var current: MediaItem {
        if case let .loaded(detail) = libraryService.details[item.id] {
            return detail
        }
        return item
    }
}

#if DEBUG
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
#endif

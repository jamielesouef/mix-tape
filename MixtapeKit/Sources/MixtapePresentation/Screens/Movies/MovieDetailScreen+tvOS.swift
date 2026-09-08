//  MovieDetailScreen+tvOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// tvOS: a full-bleed backdrop with the metadata block anchored bottom-left (engineering doc §9,
    /// tvOS table). Play starts from the beginning and Resume from the server's position; both
    /// present `VideoPlayerScreen` as a full-screen cover. Also used for episodes from Continue Watching.
    public struct MovieDetailScreen: View {
        @Environment(\.libraryService) private var libraryService
        @Environment(\.videoPlaybackService) private var videoPlaybackService
        let item: MediaItem

        public init(item: MediaItem) {
            self.item = item
        }

        public var body: some View {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(source: .item(current, current.backdropImageTag == nil ? .primary : .backdrop), maxHeight: 1080, placeholder: "film")
                    .ignoresSafeArea()
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text(current.displayTitle)
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier(MovieDetailIdentifiers.titleLabel)
                    Text(current.detailMetadata)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if let overview = current.overview, overview.isEmpty == false {
                        Text(overview)
                            .font(.body)
                            .lineLimit(4)
                            .frame(maxWidth: 900, alignment: .leading)
                            .accessibilityIdentifier(MovieDetailIdentifiers.overviewLabel)
                    }
                    HStack(spacing: 24) {
                        Button("Play", systemImage: "play.fill") { play(from: .zero) }
                            .accessibilityIdentifier(MovieDetailIdentifiers.playButton)
                        if current.playback.hasResumePoint {
                            Button("Resume", systemImage: "playpause.fill") { play(from: current.playback.position) }
                                .accessibilityIdentifier(MovieDetailIdentifiers.resumeButton)
                        }
                    }
                    if let fraction = current.progressFraction {
                        ProgressView(value: fraction)
                            .tint(.accentColor)
                            .frame(maxWidth: 400)
                    }
                    if case let .failed(error) = libraryService.details[item.id] {
                        Text(error.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(80)
            }
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
#endif

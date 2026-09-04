//  EpisodeList.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// The episodes of one season, from `SeriesService.episodes`.
struct EpisodeList: View {
    @Environment(\.seriesService) private var seriesService
    let seriesID: String
    let seasonID: String

    var body: some View {
        switch seriesService.episodes[seasonID] {
        case .none, .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(error):
            RetryView(error: error) { await seriesService.loadEpisodes(seriesID: seriesID, seasonID: seasonID) }
        case let .loaded(episodes) where episodes.isEmpty:
            ContentUnavailableView("No episodes", systemImage: "tv")
        case let .loaded(episodes):
            List(episodes) { episode in
                NavigationLink(value: episode) {
                    EpisodeRow(episode: episode)
                }
                .accessibilityIdentifier(SeriesDetailIdentifiers.episodeRow(episode.id))
            }
            .accessibilityIdentifier(SeriesDetailIdentifiers.episodeList)
        }
    }
}

#if DEBUG
    #Preview("loaded") {
        NavigationStack {
            EpisodeList(seriesID: "series-1", seasonID: "season-1")
        }
        .environment(\.seriesService, MockSeriesService.loaded())
    }

    #Preview("empty") {
        NavigationStack {
            EpisodeList(seriesID: "series-1", seasonID: "season-2")
        }
        .environment(\.seriesService, MockSeriesService.loaded())
    }

    #Preview("failure") {
        NavigationStack {
            EpisodeList(seriesID: "series-1", seasonID: "season-1")
        }
        .environment(\.seriesService, MockSeriesService.make(episodes: ["season-1": .failed(.serverUnreachable)]))
    }
#endif

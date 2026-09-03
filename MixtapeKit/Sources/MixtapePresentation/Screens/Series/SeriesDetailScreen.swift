//  SeriesDetailScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// Season picker → episode list. Episodes arrive sorted by the repository (decision 27).
public struct SeriesDetailScreen: View {
    @Environment(\.seriesService) private var seriesService
    @State private var selectedSeasonID: String?
    let series: MediaItem

    public init(series: MediaItem) {
        self.series = series
    }

    public var body: some View {
        Group {
            switch seriesService.seasons[series.id] {
            case .none, .idle, .loading:
                ProgressView()
            case let .failed(error):
                RetryView(error: error) { await seriesService.loadSeasons(seriesID: series.id) }
            case let .loaded(seasons) where seasons.isEmpty:
                ContentUnavailableView("No seasons", systemImage: "tv")
            case let .loaded(seasons):
                VStack(spacing: 0) {
                    Picker("Season", selection: Binding(get: { currentSeasonID ?? "" }, set: { selectedSeasonID = $0 })) {
                        ForEach(seasons) { season in
                            Text(season.name).tag(season.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .accessibilityIdentifier(SeriesDetailIdentifiers.seasonPicker)
                    episodeList
                }
            }
        }
        .navigationTitle(series.name)
        .task { await seriesService.loadSeasons(seriesID: series.id) }
        .task(id: currentSeasonID) {
            if let currentSeasonID {
                await seriesService.loadEpisodes(seriesID: series.id, seasonID: currentSeasonID)
            }
        }
    }

    private var currentSeasonID: String? {
        if let selectedSeasonID {
            return selectedSeasonID
        }
        if case let .loaded(seasons) = seriesService.seasons[series.id] {
            return seasons.first?.id
        }
        return nil
    }

    private var episodeList: EpisodeList {
        EpisodeList(seriesID: series.id, seasonID: currentSeasonID ?? "")
    }
}

#Preview("loaded") {
    NavigationStack {
        SeriesDetailScreen(series: MockMedia.series)
    }
    .environment(\.seriesService, MockSeriesService.loaded())
}

#Preview("empty") {
    NavigationStack {
        SeriesDetailScreen(series: MockMedia.series)
    }
    .environment(\.seriesService, MockSeriesService.empty())
}

#Preview("failure") {
    NavigationStack {
        SeriesDetailScreen(series: MockMedia.series)
    }
    .environment(\.seriesService, MockSeriesService.failed())
}

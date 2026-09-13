//  SeriesDetailIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public enum SeriesDetailIdentifiers {
    public static let seasonPicker = "seriesDetail.seasonPicker"
    public static let episodeList = "seriesDetail.episodeList"

    public static func seasonOption(_ seasonID: String) -> String {
        "seriesDetail.seasonOption.\(seasonID)"
    }

    public static func episodeRow(_ itemID: String) -> String {
        "seriesDetail.episodeRow.\(itemID)"
    }
}

//  PlaybackMapper.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated enum PlaybackMapper {
    static func body(from report: PlaybackReport) -> PlaybackReportBody {
        PlaybackReportBody(
            itemId: report.itemID,
            mediaSourceId: report.mediaSourceID,
            playSessionId: report.playSessionID,
            positionTicks: report.position.ticks,
            isPaused: report.isPaused,
            playMethod: wireName(report.playMethod),
        )
    }

    static func wireName(_ method: PlayMethod) -> String {
        switch method {
        case .directPlay: "DirectPlay"
        case .directStream: "DirectStream"
        case .transcode: "Transcode"
        }
    }
}

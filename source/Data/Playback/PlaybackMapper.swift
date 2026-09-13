//  PlaybackMapper.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated enum PlaybackMapper {
    static func resolution(from dto: PlaybackInfoResponseDTO) throws -> VideoSourceResolution {
        guard let playSessionID = dto.playSessionId else { throw MixtapeError.decoding }
        return VideoSourceResolution(playSessionID: playSessionID, sources: (dto.mediaSources ?? []).compactMap(candidate))
    }

    static func candidate(from dto: MediaSourceInfoDTO) -> MediaSourceCandidate? {
        guard let id = dto.id else { return nil }
        let streams = dto.mediaStreams ?? []
        return MediaSourceCandidate(
            id: id,
            container: dto.container ?? "",
            videoCodec: streams.first { $0.type == "Video" }?.codec,
            audioCodec: streams.first { $0.type == "Audio" }?.codec,
            supportsDirectPlay: dto.supportsDirectPlay ?? false,
            supportsDirectStream: dto.supportsDirectStream ?? false,
            transcodingUrl: dto.transcodingUrl,
            runTimeTicks: dto.runTimeTicks,
        )
    }

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

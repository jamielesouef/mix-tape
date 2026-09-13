//  IsAVPlayerNativeTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.domain))
struct IsAVPlayerNativeTests {
    @Test(arguments: [
        ("mp4", "h264", "aac", true),
        ("mkv", "h264", "aac", false),
        ("mkv", "hevc", "dts", false),
        ("mov", "hevc", "ac3", true),
        ("webm", "vp9", "opus", false),
        ("mp4", "h264", "dts", false),
        ("mp4", "av1", "aac", false),
        ("mp4", "h264", nil, true),
        ("mkv", "h264", nil, false),
    ] as [(String, String?, String?, Bool)])
    func `fixture table`(container: String, videoCodec: String?, audioCodec: String?, expected: Bool) {
        #expect(isAVPlayerNative(container: container, videoCodec: videoCodec, audioCodec: audioCodec) == expected)
    }

    @Test func `comparison ignores case`() {
        #expect(isAVPlayerNative(container: "MP4", videoCodec: "H264", audioCodec: "AAC"))
    }

    @Test func `missing video codec is not native`() {
        #expect(isAVPlayerNative(container: "mp4", videoCodec: nil, audioCodec: "aac") == false)
    }
}

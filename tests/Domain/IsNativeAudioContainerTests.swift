//  IsNativeAudioContainerTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.domain))
struct IsNativeAudioContainerTests {
    @Test(arguments: [
        ("flac", true),
        ("mov,mp4,m4a,3gp,3g2,mj2", true),
        ("mp3", true),
        (nil as String?, true),
        ("opus", false),
        ("ogg,vorbis", false),
    ])
    func `native containers direct-stream, exotic ones transcode`(container: String?, native: Bool) {
        #expect(isNativeAudioContainer(container) == native)
    }
}

//  RouteChangeActionTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import AVFoundation
import Testing
@testable import Mixtape

@Suite(.tags(.repository))
struct RouteChangeActionTests {
    @Test
    func `an old device becoming unavailable pauses`() {
        let reason = AVAudioSession.RouteChangeReason.oldDeviceUnavailable
        #expect(shouldPause(forRouteChangeReason: reason.rawValue))
    }

    @Test
    func `a new device becoming available does not pause`() {
        let reason = AVAudioSession.RouteChangeReason.newDeviceAvailable
        #expect(shouldPause(forRouteChangeReason: reason.rawValue) == false)
    }

    @Test
    func `an unrecognised raw value does not pause`() {
        #expect(shouldPause(forRouteChangeReason: .max) == false)
    }
}

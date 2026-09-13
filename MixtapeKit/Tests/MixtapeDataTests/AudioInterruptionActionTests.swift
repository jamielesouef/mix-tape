//  AudioInterruptionActionTests.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import AVFoundation
import MixtapeInfrastructure
import Testing

@Suite(.tags(.repository))
struct AudioInterruptionActionTests {
    @Test func `an interruption begin always pauses`() {
        #expect(audioInterruptionAction(type: .began, options: []) == .pause)
    }

    @Test func `an interruption end with shouldResume resumes`() {
        #expect(audioInterruptionAction(type: .ended, options: .shouldResume) == .resume)
    }

    @Test func `an interruption end without shouldResume stays paused`() {
        #expect(audioInterruptionAction(type: .ended, options: []) == .none)
    }
}

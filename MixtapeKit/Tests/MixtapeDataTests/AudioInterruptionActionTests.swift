//  AudioInterruptionActionTests.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import AVFoundation
import MixtapeInfrastructure
import Testing

/// AC23a. Lives here per fork F1 (Infrastructure has no test target of its own), matching
/// `RedactingURLsTests`'s precedent exactly: `audioInterruptionAction` is pure and takes the
/// system's own enums, so it is testable without a live `AVAudioSession`.
///
/// Three plain `@Test`s rather than one parameterised test: `AudioInterruptionAction` is not
/// `Sendable` (it is production code, not touched here), and a parameterised test's argument
/// array must cross into the testing library's own executor, which requires exactly that.
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

//  RedactingURLsTests.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import MixtapeInfrastructure
import Testing

/// Lives here per fork F1: Infrastructure has no test target of its own.
@Suite(.tags(.repository))
struct RedactingURLsTests {
    @Test func `every URL in a libVLC message is replaced and the rest survives`() {
        let message = "http input: opening http://localhost:8096/Videos/abc/stream?static=true&ApiKey=secret-token failed, retrying https://nas.home:8920/x?deviceId=d1"
        let redacted = redactingURLs(message)
        #expect(redacted == "http input: opening <url> failed, retrying <url>")
        #expect(redacted.contains("secret-token") == false)
        #expect(redactingURLs("no url here") == "no url here")
    }
}

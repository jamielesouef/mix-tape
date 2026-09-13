//  ImageServiceTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import Mixtape
import Testing
import UIKit

@Suite(.tags(.service))
@MainActor
struct ImageServiceTests {
    private let service = MockImageService.make()

    @Test func `a track without its own art falls back to the album`() {
        let track = MockLibraryRepository.sampleTracks[0]
        let url = service.imageURL(for: track, kind: .primary, maxHeight: 300)
        #expect(url?.absoluteString == "mock://images/album-1/Primary?tag=a1&maxHeight=300")
    }

    @Test func `an item without a tag has no url and no image`() async {
        let album = MockLibraryRepository.sampleAlbums[0]
        #expect(service.imageURL(for: album, kind: .primary, maxHeight: 300) != nil)
        let untagged = MockLibraryRepository.sampleLibraries[1]
        #expect(service.imageURL(for: untagged, maxHeight: 300) == nil)
        #expect(await service.image(for: untagged, maxHeight: 300) == nil)
    }

    @Test func `no session means no url`() {
        let signedOut = MockImageService.make(sessionService: MockSessionService.signedOut())
        #expect(signedOut.imageURL(for: MockLibraryRepository.sampleAlbums[0], kind: .primary, maxHeight: 300) == nil)
    }

    // MARK: Slice 023 — ImageService hardening (AC23c)

    @Test func `AC23c two concurrent requests for the same url are coalesced into one network call`() async throws {
        let url = try #require(URL(string: "https://\(UUID()).stub/img.png"))
        let log = ReportLog()
        let gate = Gate()
        gate.close()
        let imageData = Self.fixturePNGData()
        StubImageURLProtocol.register(url) {
            log.append("fetch")
            await gate.wait()
            return (200, imageData)
        }
        let networked = ImageService(builder: MockImageURLBuilder(), sessionService: MockSessionService.signedIn(), urlSession: StubImageURLProtocol.session)
        async let first = networked.image(at: url)
        async let second = networked.image(at: url)
        await log.waitForCount(1)
        gate.open()
        let (a, b) = await (first, second)
        #expect(a != nil)
        #expect(a === b)
        #expect(log.entries.count == 1)
    }

    @Test func `AC23c a non-2xx response yields nil instead of decoding the body`() async throws {
        let url = try #require(URL(string: "https://\(UUID()).stub/missing.png"))
        let imageData = Self.fixturePNGData()
        StubImageURLProtocol.register(url) { (404, imageData) }
        let networked = ImageService(builder: MockImageURLBuilder(), sessionService: MockSessionService.signedIn(), urlSession: StubImageURLProtocol.session)
        let image = await networked.image(at: url)
        #expect(image == nil)
    }

    @Test func `AC23c cache cost is the decoded pixel size, not the compressed byte count`() throws {
        let imageData = Self.fixturePNGData()
        let image = try #require(UIImage(data: imageData))
        let cgImage = try #require(image.cgImage)
        let cost = ImageService.cost(of: image)
        #expect(cost == cgImage.width * cgImage.height * 4)
        #expect(cost != imageData.count)
    }

    private static func fixturePNGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        return renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}

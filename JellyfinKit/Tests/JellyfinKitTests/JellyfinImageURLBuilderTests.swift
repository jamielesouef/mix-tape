//  JellyfinImageURLBuilderTests.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import Testing
@testable import JellyfinKit

@Suite(.tags(.repository))
struct JellyfinImageURLBuilderTests {
    private let builder = JellyfinImageURLBuilder()
    private let server = URL(string: "http://localhost:8096")!

    @Test
    func `primary image uses max height and the tag`() {
        let url = builder.url(
            serverURL: server,
            itemID: "item-1",
            tag: "abc",
            type: .primary,
            maxHeight: 300
        )

        #expect(url?
            .absoluteString ==
            "http://localhost:8096/Items/item-1/Images/Primary?tag=abc&maxHeight=300&quality=90")
    }

    @Test
    func `backdrop image uses index zero`() {
        let url = builder.url(
            serverURL: server,
            itemID: "item-1",
            tag: "abc",
            type: .backdrop,
            maxHeight: 720
        )

        #expect(url?.path() == "/Items/item-1/Images/Backdrop/0")
    }

    @Test
    func `no tag means no url`() {
        let url = builder.url(
            serverURL: server,
            itemID: "item-1",
            tag: nil,
            type: .primary,
            maxHeight: 300
        )

        #expect(url == nil)
    }
}

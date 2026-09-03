//  JellyfinImageURLBuilderTests.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
@testable import MixtapeData
import MixtapeDomain
import Testing

@Suite(.tags(.repository))
struct JellyfinImageURLBuilderTests {
    private let builder = JellyfinImageURLBuilder()
    private let session = UserSession(
        serverURL: URL(string: "http://localhost:8096")!, // test constant
        userID: "user-1", userName: "jamie", accessToken: "tok-1", deviceID: "device-1",
    )

    @Test func `primary image uses max height and the tag`() {
        let url = builder.url(itemID: "item-1", tag: "abc", kind: .primary, maxHeight: 300, session: session)
        #expect(url?.absoluteString == "http://localhost:8096/Items/item-1/Images/Primary?tag=abc&maxHeight=300&quality=90")
    }

    @Test func `backdrop image uses index zero`() {
        let url = builder.url(itemID: "item-1", tag: "abc", kind: .backdrop, maxHeight: 720, session: session)
        #expect(url?.path() == "/Items/item-1/Images/Backdrop/0")
        #expect(url?.query()?.contains("fillHeight") == false)
    }

    @Test func `no tag means no url`() {
        #expect(builder.url(itemID: "item-1", tag: nil, kind: .primary, maxHeight: 300, session: session) == nil)
    }
}

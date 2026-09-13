//  LibraryTabResolutionTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 05/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.presentation))
@MainActor
struct LibraryTabResolutionTests {
    private let one = MockMedia.libraries
    private let secondMusic = Library(id: "lib-music-2", name: "Music 2", kind: .music, imageTag: nil)

    @Test func `a single library of the kind is hosted directly, as 011 shipped it`() {
        #expect(LibraryTabResolution(kind: .music, in: one) == .one(one[0]))
    }

    @Test func `several libraries of the kind become a list, in the server's order`() {
        let libraries = one + [secondMusic]
        #expect(LibraryTabResolution(kind: .music, in: libraries) == .several([one[0], secondMusic]))
        #expect(LibraryTabResolution(kind: .music, in: [secondMusic] + one) == .several([secondMusic, one[0]]))
    }

    @Test func `no library of the kind is the empty state, whatever else the user has`() {
        #expect(LibraryTabResolution(kind: .music, in: []) == .none)
    }
}

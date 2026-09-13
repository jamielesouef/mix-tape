//  StubVideoPlayerController.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import SwiftUI
@testable import Mixtape

@MainActor
final class StubVideoPlayerController: VideoPlayerControlling {
    var onPositionChange: ((Duration) -> Void)?
    var onTransportEvent: ((VideoTransportEvent) -> Void)?
    var onEnded: (() -> Void)?
    var onFailure: ((MixtapeError) -> Void)?
    private(set) var calls: [String] = []
    private(set) var loadedURL: URL?
    private(set) var loadedStart: Duration?

    func load(url: URL, startAt: Duration, headers: [String: String]) {
        loadedURL = url
        loadedStart = startAt
        calls.append("load headers=\(headers.count)")
    }

    func play() {
        calls.append("play")
        onTransportEvent?(.resumed)
    }

    func pause() {
        calls.append("pause")
        onTransportEvent?(.paused)
    }

    func seek(to position: Duration) {
        calls.append("seek \(position.components.seconds)")
        onTransportEvent?(.seeked(position))
    }

    func teardown() {
        calls.append("teardown")
    }

    func makeView() -> AnyView {
        AnyView(EmptyView())
    }
}

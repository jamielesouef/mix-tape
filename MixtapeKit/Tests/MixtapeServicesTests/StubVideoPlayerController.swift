//  StubVideoPlayerController.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure
import SwiftUI

/// Records every call and lets a test fire the player callbacks.
@MainActor
final class StubVideoPlayerController: VideoPlayerControlling {
    var onPositionChange: ((Duration) -> Void)?
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
    }

    func pause() {
        calls.append("pause")
    }

    func seek(to position: Duration) {
        calls.append("seek \(position.components.seconds)")
    }

    func teardown() {
        calls.append("teardown")
    }

    func makeView() -> AnyView {
        AnyView(EmptyView())
    }
}

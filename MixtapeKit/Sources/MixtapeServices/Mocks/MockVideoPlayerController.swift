//  MockVideoPlayerController.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure
import SwiftUI

/// A `VideoPlayerControlling` that plays nothing: previews get a black view and a controller that
/// answers every call. `Stub*` doubles for tests live in the test targets.
public final class MockVideoPlayerController: VideoPlayerControlling {
    public var onPositionChange: ((Duration) -> Void)?
    public var onEnded: (() -> Void)?
    public var onFailure: ((MixtapeError) -> Void)?
    public private(set) var loadedURL: URL?

    public init() {}

    public func load(url: URL, startAt _: Duration, headers _: [String: String]) {
        loadedURL = url
    }

    public func play() {}
    public func pause() {}
    public func seek(to _: Duration) {}

    public func teardown() {
        loadedURL = nil
    }

    public func makeView() -> AnyView {
        AnyView(Color.black)
    }
}

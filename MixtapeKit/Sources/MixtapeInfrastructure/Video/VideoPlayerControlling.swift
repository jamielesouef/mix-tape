//  VideoPlayerControlling.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import SwiftUI

/// Engineering doc §7. One conformer per player; Presentation only ever sees this protocol and
/// the `AnyView` it hands back. `headers` is kept for the contract and is empty under decision 42.
/// `onTransportEvent` is the player's own account of pause, resume and seek completion (slice
/// 014): whoever drove the transport, the service learns of it here and nowhere else.
@MainActor
public protocol VideoPlayerControlling: AnyObject {
    var onPositionChange: ((Duration) -> Void)? { get set }
    var onTransportEvent: ((VideoTransportEvent) -> Void)? { get set }
    var onEnded: (() -> Void)? { get set }
    var onFailure: ((MixtapeError) -> Void)? { get set }
    func load(url: URL, startAt: Duration, headers: [String: String])
    func play()
    func pause()
    func seek(to position: Duration)
    func teardown()
    func makeView() -> AnyView
}

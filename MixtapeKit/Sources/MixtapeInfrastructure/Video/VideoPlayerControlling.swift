//  VideoPlayerControlling.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import SwiftUI

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

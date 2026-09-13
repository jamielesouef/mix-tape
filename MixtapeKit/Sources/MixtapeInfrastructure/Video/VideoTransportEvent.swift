//  VideoTransportEvent.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Foundation

public nonisolated enum VideoTransportEvent: Sendable, Equatable {
    case paused
    case resumed
    case seeked(Duration)
}

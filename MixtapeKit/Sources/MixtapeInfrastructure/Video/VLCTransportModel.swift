//  VLCTransportModel.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Observation

/// The VLC overlay's observable state. VLC drives it; the SwiftUI overlay reads it.
@Observable
final class VLCTransportModel {
    var isPlaying = false
    var positionFraction: Double = 0
}

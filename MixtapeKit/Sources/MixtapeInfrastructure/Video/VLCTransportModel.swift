//  VLCTransportModel.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Observation

@Observable
final class VLCTransportModel {
    var isPlaying = false
    var positionFraction: Double = 0
}

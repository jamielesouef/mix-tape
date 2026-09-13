//  DeviceName.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import UIKit

enum DeviceName {
    @MainActor static var current: String {
        UIDevice.current.name
    }
}

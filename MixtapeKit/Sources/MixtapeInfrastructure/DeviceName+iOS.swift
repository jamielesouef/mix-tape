//  DeviceName+iOS.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS)
    import UIKit

    /// The `Device` component of the Authorization header.
    nonisolated enum DeviceName {
        @MainActor static var current: String {
            UIDevice.current.name
        }
    }
#endif

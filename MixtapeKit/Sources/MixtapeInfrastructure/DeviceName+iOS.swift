//  DeviceName+iOS.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS)
    import UIKit

    /// The `Device` component of the Authorization header.
    public nonisolated enum DeviceName {
        @MainActor public static var current: String {
            UIDevice.current.name
        }
    }
#endif

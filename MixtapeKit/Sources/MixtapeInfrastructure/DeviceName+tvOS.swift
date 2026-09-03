//  DeviceName+tvOS.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(tvOS)
    /// The `Device` component of the Authorization header.
    public nonisolated enum DeviceName {
        @MainActor public static var current: String {
            "Apple TV"
        }
    }
#endif

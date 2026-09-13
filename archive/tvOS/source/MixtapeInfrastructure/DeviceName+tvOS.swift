//  DeviceName+tvOS.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(tvOS)
    public nonisolated enum DeviceName {
        @MainActor public static var current: String {
            "Apple TV"
        }
    }
#endif

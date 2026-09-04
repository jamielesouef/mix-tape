//  SplashScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

public struct SplashScreen: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("mixtape")
                .font(.largeTitle.bold())
            ProgressView()
        }
        .accessibilityIdentifier("splash")
    }
}

#if DEBUG
    #Preview {
        SplashScreen()
    }
#endif

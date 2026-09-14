//  SplashScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct SplashScreen: View {
    init() {}

    var body: some View {
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

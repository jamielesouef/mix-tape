//  RootTabScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

/// The signed-in root. One tab, so the mini player can dock in the tab bar's bottom
/// accessory (iOS 26.1) rather than fighting a second surface for space; Now Playing is a
/// sheet presented from here so it outlives the mini player that opened it.
struct RootTabScreen: View {
    // MARK: - Properties

    @State private var isPresentingNowPlaying = false

    init() {}

    // MARK: - Body

    var body: some View {
        TabView {
            Tab("Wallets", systemImage: "rectangle.stack.fill") {
                WalletsHomeScreen()
            }
            .accessibilityIdentifier(RootTabIdentifiers.walletsTab)
        }
        // glass-fallback: the accessory bar's own glass is system-drawn, but MiniPlayer's
        // content inside it goes through GlassChrome, which reads Reduce Transparency itself.
        .tabViewBottomAccessory {
            MiniPlayer(showNowPlaying: $isPresentingNowPlaying)
        }
        .sheet(isPresented: $isPresentingNowPlaying) {
            NowPlayingScreen()
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        RootTabScreen()
            .environment(\.walletsService, MockWalletsService.loaded())
            .environment(\.musicPlayerService, MockMusicPlayerService.playing())
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        RootTabScreen()
            .environment(\.walletsService, MockWalletsService.empty())
            .environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }

    #Preview("failure") {
        RootTabScreen()
            .environment(\.walletsService, MockWalletsService.failed())
            .environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }
#endif

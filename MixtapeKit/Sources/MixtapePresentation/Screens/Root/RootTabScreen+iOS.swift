//  RootTabScreen+iOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS)
    import MixtapeServices
    import SwiftUI

    public struct RootTabScreen: View {
        @Environment(\.musicPlayerService) private var music
        @State private var showNowPlaying = false

        public init() {}

        public var body: some View {
            TabView {
                Tab("Home", systemImage: "house") {
                    HomeScreen()
                }
                .accessibilityIdentifier(RootTabIdentifiers.homeTab)
                Tab("Libraries", systemImage: "books.vertical") {
                    LibraryListScreen()
                }
                .accessibilityIdentifier(RootTabIdentifiers.librariesTab)
                Tab("Music", systemImage: "music.note") {
                    MusicTabScreen()
                }
                .accessibilityIdentifier(RootTabIdentifiers.musicTab)
                Tab("Settings", systemImage: "gear") {
                    NavigationStack {
                        SettingsScreen().navigationTitle("Settings")
                    }
                }
                .accessibilityIdentifier(RootTabIdentifiers.settingsTab)
            }
            .tabViewBottomAccessory(isEnabled: music.isActive) {
                MiniPlayer(showNowPlaying: $showNowPlaying)
            }
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingScreen()
            }
            .onChange(of: music.isActive) { _, active in
                if active == false {
                    showNowPlaying = false
                }
            }
        }
    }

    #if DEBUG
        #Preview("loaded") {
            RootTabScreen()
                .environment(\.sessionService, MockSessionService.signedIn())
                .environment(\.libraryService, MockLibraryService.loaded())
        }

        #Preview("empty") {
            RootTabScreen()
                .environment(\.sessionService, MockSessionService.signedIn())
                .environment(\.libraryService, MockLibraryService.empty())
        }

        #Preview("failure") {
            RootTabScreen()
                .environment(\.sessionService, MockSessionService.signedIn())
                .environment(\.libraryService, MockLibraryService.failed())
        }
    #endif
#endif

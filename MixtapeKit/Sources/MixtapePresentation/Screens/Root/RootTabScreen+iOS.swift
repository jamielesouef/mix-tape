//  RootTabScreen+iOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS)
    import MixtapeServices
    import SwiftUI

    /// iOS: Home, Libraries, Music, Settings (engineering doc §9). The mini player docks above
    /// the tab bar in slice 009; nothing is reserved for it here beyond this comment.
    public struct RootTabScreen: View {
        public init() {}

        public var body: some View {
            TabView {
                Tab("Home", systemImage: "house") {
                    HomeScreen().accessibilityIdentifier(RootTabIdentifiers.homeTab)
                }
                Tab("Libraries", systemImage: "books.vertical") {
                    LibraryListScreen().accessibilityIdentifier(RootTabIdentifiers.librariesTab)
                }
                Tab("Music", systemImage: "music.note") {
                    MusicTabScreen().accessibilityIdentifier(RootTabIdentifiers.musicTab)
                }
                Tab("Settings", systemImage: "gear") {
                    NavigationStack {
                        SettingsScreen().navigationTitle("Settings")
                    }
                    .accessibilityIdentifier(RootTabIdentifiers.settingsTab)
                }
            }
            .tabViewBottomAccessory {
                MiniPlayer()
            }
        }
    }

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

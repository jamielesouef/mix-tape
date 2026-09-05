//  RootTabScreen+tvOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import MixtapeServices
    import SwiftUI

    /// tvOS: Home, Movies, Shows, Music, Settings across the top (decision 26). No mini player and no
    /// wallet — §1.1 keeps the wallet iOS-only and tvOS on conventional shelves.
    public struct RootTabScreen: View {
        public init() {}

        public var body: some View {
            // Identifiers sit on the tabs themselves (§9 "every interactive element"), so the tab-bar
            // items can be addressed to switch tabs — not only the content behind them (slice 016).
            TabView {
                Tab("Home", systemImage: "house") {
                    HomeScreen()
                }
                .accessibilityIdentifier(RootTabIdentifiers.homeTab)
                Tab("Movies", systemImage: "film") {
                    LibraryTabScreen(kind: .movies)
                }
                .accessibilityIdentifier(RootTabIdentifiers.moviesTab)
                Tab("Shows", systemImage: "tv") {
                    LibraryTabScreen(kind: .tvShows)
                }
                .accessibilityIdentifier(RootTabIdentifiers.showsTab)
                Tab("Music", systemImage: "music.note") {
                    LibraryTabScreen(kind: .music)
                }
                .accessibilityIdentifier(RootTabIdentifiers.musicTab)
                Tab("Settings", systemImage: "gear") {
                    NavigationStack {
                        SettingsScreen().navigationTitle("Settings")
                    }
                }
                .accessibilityIdentifier(RootTabIdentifiers.settingsTab)
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

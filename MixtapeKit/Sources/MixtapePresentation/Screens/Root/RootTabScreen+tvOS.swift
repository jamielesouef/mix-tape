//  RootTabScreen+tvOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(tvOS)
    import MixtapeServices
    import SwiftUI

    /// tvOS: the minimal counterpart that keeps the scheme building. Slice 011 replaces it with
    /// the five-tab shelf chrome (Home / Movies / Shows / Music / Settings, decision 26).
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

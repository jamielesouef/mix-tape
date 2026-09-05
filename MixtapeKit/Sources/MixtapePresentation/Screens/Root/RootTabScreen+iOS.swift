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
        @Environment(\.musicPlayerService) private var music
        @State private var showNowPlaying = false

        public init() {}

        public var body: some View {
            // Identifiers on the tabs themselves, so the tab-bar items can be addressed (slice 016,
            // Triage 17 — the same gap as tvOS, closed with the same modifier).
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
            // iOS 26.1 (decision 48): with nothing playing the accessory container itself must go,
            // or an empty pill sits over the bottom of every tab (Triage 9).
            //
            // glass-fallback: the container is system-drawn Liquid Glass and renders opaque
            // under Reduce Transparency on its own — measured, not assumed (spike S003,
            // 2026-09-04, iOS 26.5 simulator: zero pixel shift in the container margins with
            // content scrolling beneath, versus visible bleed with the setting off). There is
            // no accessory-background API on 26.1 to override it. The app-drawn pill inside it
            // carries its own fallback via MiniPlayer's .glassChrome(); painting an opaque rect
            // in here as well would sit a solid block inside an already-opaque container.
            .tabViewBottomAccessory(isEnabled: music.isActive) {
                MiniPlayer(showNowPlaying: $showNowPlaying)
            }
            // The sheet lives here, on the one view that outlives the music, so that its dismissal
            // is this line and not the accessory being torn out from under it (slice 015, §9.1
            // step 1). `isActive` turns false at the end of an album and on stop().
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

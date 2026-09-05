//  WalletScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// The CD wallet (engineering doc §9.1): sideways pages of sleeves for one music library. Tapping
    /// a sleeve pulls the disc out into `AlbumDetailScreen`; when the album plays to its end the
    /// wallet dismisses now-playing, pops the detail, pages to the sleeve and pulses it home. Hosted
    /// as the Music tab's root and pushed from the Libraries tab, so it owns the pushed album rather
    /// than the navigation stack.
    public struct WalletScreen: View {
        @Environment(\.libraryService) private var libraryService
        @Environment(\.musicPlayerService) private var music
        @Environment(\.horizontalSizeClass) private var sizeClass
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Namespace private var sleeves
        @State private var pageIndex = 0
        @State private var pulledAlbum: MediaItem?
        @State private var pulsingAlbumID: String?
        @State private var isVisible = false
        let library: Library

        public init(library: Library) {
            self.library = library
        }

        public var body: some View {
            VStack(spacing: 12) {
                TabView(selection: $pageIndex) {
                    ForEach(0 ..< pageCount, id: \.self) { page in
                        WalletPage(albums: albums(onPage: page), columns: columns, pulsingAlbumID: pulsingAlbumID, namespace: sleeves) { pulledAlbum = $0 }
                            .tag(page)
                            // A container of its own, or the page identifier cascades onto every sleeve.
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier(WalletIdentifiers.page(page))
                            .task {
                                if page == pageCount - 1 {
                                    await libraryService.loadMore(libraryID: library.id)
                                }
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier(WalletIdentifiers.pager)
                switch phase {
                case .loading:
                    ProgressView()
                        .controlSize(.small)
                case let .failed(error):
                    Text(error.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await libraryService.loadLibrary(id: library.id) } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(WalletIdentifiers.retryButton)
                case .empty:
                    Text("No albums in this library yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(WalletIdentifiers.emptyLabel)
                case .loaded:
                    Text("Page \(pageIndex + 1) of \(pageCount)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(WalletIdentifiers.pageIndicator)
                }
            }
            .padding(.bottom)
            .navigationTitle(library.name)
            .navigationDestination(item: $pulledAlbum) { album in
                AlbumDetailScreen(album: album)
                    .navigationTransition(.zoom(sourceID: album.id, in: sleeves))
                    // §9.1 step 1: the pulled disc goes back on its own. A NavigationStack root
                    // covered by a pushed destination is not updated (measured, slice 015), so the
                    // wallet underneath cannot pop it — but this modifier rides on the pushed view.
                    .onChange(of: music.finishedAlbumID) { _, finished in
                        if finished == album.id {
                            pulledAlbum = nil
                        }
                    }
            }
            .task { await libraryService.loadLibrary(id: library.id) }
            // Appearing is how a wallet learns of a finish it was covered for: its own detail just
            // popped, or the user came back to this tab. Animated when the scene is live, so the
            // pulse plays after the pop; unanimated from the background (§9.1).
            .onAppear {
                isVisible = true
                returnToSleeveIfFinished(animated: scenePhase == .active)
            }
            .onDisappear { isVisible = false }
            // Act on the value delivered, never on a re-read of the service (slice 015).
            .onChange(of: music.finishedAlbumID) { _, finished in
                if let finished {
                    returnToSleeve(albumID: finished, animated: scenePhase == .active)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    returnToSleeveIfFinished(animated: false)
                }
            }
            .onChange(of: pageCount) { _, count in
                pageIndex = min(pageIndex, count - 1)
            }
            // Paged in further for an off-page finish (AC15d): try again with the albums we now have.
            .onChange(of: pager.albums.count) { _, _ in
                returnToSleeveIfFinished(animated: scenePhase == .active)
            }
        }

        private var columns: Int {
            sizeClass == .regular ? 3 : 2
        }

        private var pager: WalletPager {
            WalletPager(state: libraryService.pages[library.id], columns: columns)
        }

        private var phase: ContentPhase<Page<MediaItem>> {
            ContentPhase(libraryService.pages[library.id]) { $0.items.isEmpty }
        }

        private var pageCount: Int {
            pager.pageCount
        }

        private func albums(onPage page: Int) -> [MediaItem] {
            pager.albums(onPage: page)
        }

        /// The backgrounded case (§9.1): the last track ended while the app was away, so the wallet
        /// is already in its finished state when it next appears or the scene becomes active.
        private func returnToSleeveIfFinished(animated: Bool) {
            if let albumID = music.finishedAlbumID {
                returnToSleeve(albumID: albumID, animated: animated)
            }
        }

        /// §9.1 "putting it back", the wallet's half: the wallet on screen claims the return — the
        /// service answers exactly one claimant per finish — pages, pulses and acknowledges. A wallet
        /// that is not on screen does nothing now and asks again when it appears, so a hidden tab
        /// can never take the return from the wallet the user is looking at, and a finish nobody is
        /// looking at waits, unacknowledged, for the first wallet that is.
        private func returnToSleeve(albumID: String, animated: Bool) {
            guard isVisible else { return }
            guard case let .honour(page) = WalletReturn(finished: albumID, pager: pager) else {
                Task { await libraryService.loadMore(libraryID: library.id) } // AC15d
                return
            }
            guard music.claimFinish(albumID: albumID) else { return }
            putBack(albumID: albumID, page: page, animated: animated)
        }

        /// Page to the sleeve, pulse it, acknowledge — the owner's half of the sequence.
        /// `acknowledgeFinish()` always runs at least one hop after the `onChange` that delivered the
        /// finish, so a second wallet's `onChange` never evaluates against an event already cleared.
        private func putBack(albumID: String, page: Int, animated: Bool) {
            // Reduce Motion takes the same path as a return from the background: no paging
            // animation and no pulse (slice 012).
            guard animated, reduceMotion == false else {
                pageIndex = page
                Task { music.acknowledgeFinish() }
                return
            }
            withAnimation {
                pageIndex = page
            }
            Task {
                // The sheet dismissal and the pop are UIKit transitions SwiftUI offers no completion
                // for; 0.6 s clears both, so the pulse lands on a sleeve the user can see.
                try? await Task.sleep(for: .seconds(0.6))
                // §9.1's "0.4 s border pulse" is 0.4 s *at* full accent, between two short ramps —
                // not two ramps meeting at an instant (Triage 19).
                withAnimation(.easeInOut(duration: 0.15)) {
                    pulsingAlbumID = albumID
                }
                try? await Task.sleep(for: .seconds(0.15 + 0.4))
                withAnimation(.easeInOut(duration: 0.15)) {
                    pulsingAlbumID = nil
                }
                try? await Task.sleep(for: .seconds(0.15))
                music.acknowledgeFinish()
            }
        }
    }

    #if DEBUG
        #Preview("loaded — full and partial pages") {
            NavigationStack {
                WalletScreen(library: MockMedia.libraries[2])
            }
            .environment(\.libraryService, MockLibraryService.loaded())
            .environment(\.imageService, MockImageService.make())
        }

        #Preview("empty") {
            NavigationStack {
                WalletScreen(library: MockMedia.libraries[2])
            }
            .environment(\.libraryService, MockLibraryService.empty())
        }

        #Preview("failure") {
            NavigationStack {
                WalletScreen(library: MockMedia.libraries[2])
            }
            .environment(\.libraryService, MockLibraryService.failed())
        }
    #endif
#endif

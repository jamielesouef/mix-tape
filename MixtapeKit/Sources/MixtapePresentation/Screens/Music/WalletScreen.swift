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
        @Namespace private var sleeves
        @State private var pageIndex = 0
        @State private var pulledAlbum: MediaItem?
        @State private var pulsingAlbumID: String?
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
                switch libraryService.pages[library.id] {
                case .none, .idle, .loading:
                    ProgressView()
                        .controlSize(.small)
                case let .failed(error):
                    Text(error.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await libraryService.loadLibrary(id: library.id) } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(WalletIdentifiers.retryButton)
                case .loaded where albums.isEmpty:
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
            }
            .task { await libraryService.loadLibrary(id: library.id) }
            .task { returnToSleeveIfFinished(animated: false) }
            .onChange(of: music.finishedAlbumID) { _, finished in
                if finished != nil {
                    returnToSleeve(animated: scenePhase == .active)
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
        }

        private var columns: Int {
            sizeClass == .regular ? 3 : 2
        }

        private var albums: [MediaItem] {
            if case let .loaded(page) = libraryService.pages[library.id] {
                return page.items
            }
            return []
        }

        private var pageCount: Int {
            WalletPosition.pageCount(albumCount: albums.count, columns: columns)
        }

        private func albums(onPage page: Int) -> [MediaItem] {
            let perPage = columns * columns
            return Array(albums.dropFirst(page * perPage).prefix(perPage))
        }

        /// The backgrounded case (§9.1): the last track ended while the app was away, so the wallet
        /// is already in its finished state when it next appears or the scene becomes active.
        private func returnToSleeveIfFinished(animated: Bool) {
            if music.finishedAlbumID != nil {
                returnToSleeve(animated: animated)
            }
        }

        /// §9.1 "putting it back": pop the detail, page to the sleeve, pulse it for 0.4 s, then
        /// acknowledge. `acknowledgeFinish()` runs last so nothing observing `finishedAlbumID`
        /// misses the change.
        private func returnToSleeve(animated: Bool) {
            guard let albumID = music.finishedAlbumID else { return }
            let page = WalletPosition(albumID: albumID, in: albums.map(\.id), columns: columns)?.page
            guard animated else {
                pulledAlbum = nil
                if let page {
                    pageIndex = page
                }
                music.acknowledgeFinish()
                return
            }
            withAnimation {
                pulledAlbum = nil
                if let page {
                    pageIndex = page
                }
            }
            Task {
                // The sheet dismissal and the pop are UIKit transitions SwiftUI offers no completion
                // for; 0.6 s clears both, so the pulse lands on a sleeve the user can see.
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.easeInOut(duration: 0.2)) {
                    pulsingAlbumID = albumID
                } completion: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pulsingAlbumID = nil
                    } completion: {
                        music.acknowledgeFinish()
                    }
                }
            }
        }
    }

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

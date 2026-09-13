//  WalletScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import SwiftUI

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
                .onChange(of: music.finishedAlbumID) { _, finished in
                    if finished == album.id {
                        pulledAlbum = nil
                    }
                }
        }
        .task { await libraryService.loadLibrary(id: library.id) }
        .onAppear {
            isVisible = true
            returnToSleeveIfFinished(animated: scenePhase == .active)
        }
        .onDisappear { isVisible = false }
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

    private func returnToSleeveIfFinished(animated: Bool) {
        if let albumID = music.finishedAlbumID {
            returnToSleeve(albumID: albumID, animated: animated)
        }
    }

    private func returnToSleeve(albumID: String, animated: Bool) {
        guard isVisible else { return }
        guard case let .honour(page) = WalletReturn(finished: albumID, pager: pager) else {
            Task { await libraryService.loadMore(libraryID: library.id) }
            return
        }
        guard music.claimFinish(albumID: albumID) else { return }
        putBack(albumID: albumID, page: page, animated: animated)
    }

    private func putBack(albumID: String, page: Int, animated: Bool) {
        guard animated, reduceMotion == false else {
            pageIndex = page
            Task { music.acknowledgeFinish() }
            return
        }
        withAnimation {
            pageIndex = page
        }
        Task {
            try? await Task.sleep(for: .seconds(0.6))
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

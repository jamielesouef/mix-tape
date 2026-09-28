//  WalletScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import SwiftUI

struct WalletScreen: View {
    // MARK: - Properties

    @Environment(\.walletsService) private var walletsService: WalletsService
    @Environment(\.musicPlayerService) private var music: MusicPlayerService
    @Environment(\.horizontalSizeClass) private var sizeClass: UserInterfaceSizeClass?
    @Environment(\.scenePhase) private var scenePhase: ScenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @Namespace private var sleeves
    @State private var pageIndex = 0
    @State private var pulledAlbum: MediaItem?
    @State private var pulsingAlbumID: String?
    @State private var isVisible = false
    @State private var isPresentingAddAlbums = false
    let wallet: Wallet

    // MARK: - Initialization

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    // MARK: - Body

    var body: some View {
        WalletPagerSection(
            pageIndex: $pageIndex,
            isPresentingAddAlbums: $isPresentingAddAlbums,
            wallet: wallet,
            pulsingAlbumID: pulsingAlbumID,
            namespace: sleeves,
            columns: columns,
            onSelect: { pulledAlbum = $0 }
        )
        .navigationDestination(item: $pulledAlbum) { album in
            AlbumDetailScreen(album: album, sequence: sequence(after: album))
                .navigationTransition(.zoom(sourceID: album.id, in: sleeves))
                .onChange(of: music.finishedAlbumID) { _, finished in
                    if finished == album.id {
                        pulledAlbum = nil
                    }
                }
        }
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
        .onChange(of: albums.count) { _, _ in
            returnToSleeveIfFinished(animated: scenePhase == .active)
        }
    }

    // MARK: - Private

    private var columns: Int {
        sizeClass == .regular ? 3 : 2
    }

    private var albums: [MediaItem] {
        walletsService.albums(for: wallet)
    }

    private var pager: WalletPager {
        WalletPager(albums: albums, columns: columns)
    }

    private var pageCount: Int {
        pager.pageCount
    }

    private func sequence(after album: MediaItem) -> [MediaItem] {
        guard let index = albums.firstIndex(where: { $0.id == album.id }) else {
            return []
        }

        return Array(albums[(index + 1)...])
    }

    private func returnToSleeveIfFinished(animated: Bool) {
        if let albumID = music.finishedAlbumID {
            returnToSleeve(albumID: albumID, animated: animated)
        }
    }

    private func returnToSleeve(albumID: String, animated: Bool) {
        guard isVisible else {
            return
        }
        guard case let .honour(page) = WalletReturn(finished: albumID, pager: pager) else {
            return
        }
        guard music.claimFinish(albumID: albumID) else {
            return
        }

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
            try? await Task.sleep(for: .seconds(PutBackTiming.pageTurnSettle))

            withAnimation(PutBackTiming.pulseAnimation) {
                pulsingAlbumID = albumID
            }

            try? await Task.sleep(for: .seconds(PutBackTiming.pulseFade + PutBackTiming.pulseHold))

            withAnimation(PutBackTiming.pulseAnimation) {
                pulsingAlbumID = nil
            }

            try? await Task.sleep(for: .seconds(PutBackTiming.pulseFade))

            music.acknowledgeFinish()
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded — full and partial pages") {
        let service = MockWalletsService.loaded()
        NavigationStack {
            WalletScreen(wallet: MockWalletsService.previewWallet)
        }
        .environment(\.walletsService, service)
        .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        NavigationStack {
            WalletScreen(wallet: MockWalletsService.previewWallet)
        }
        .environment(\.walletsService, MockWalletsService.empty())
    }

    #Preview("failure") {
        NavigationStack {
            WalletScreen(wallet: MockWalletsService.previewWallet)
        }
        .environment(\.walletsService, MockWalletsService.failed())
    }
#endif

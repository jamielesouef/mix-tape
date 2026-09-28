//  WalletsService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import Observation

/// Assembles the wallet shelf: one wallet per music library, the generated genre / most
/// played / random wallets, the Downloaded wallet, and the listener's personal wallets.
/// Album lists for the library- and personal-kind wallets follow the listener's browsing
/// order preference; the generated wallets keep the order they were built in.
@MainActor
@Observable
final class WalletsService {
    // MARK: - Properties

    private(set) var wallets: LoadState<[Wallet]> = .idle
    private(set) var randomWalletMode: RandomWalletMode

    private(set) var allAlbums: [MediaItem] = []
    private var albumsByWalletID: [String: [MediaItem]] = [:]

    private let libraryService: LibraryService
    private let downloadsService: DownloadsService
    private let settingsService: SettingsService
    private let loadPersonalWallets: LoadPersonalWalletsUseCase
    private let savePersonalWallets: SavePersonalWalletsUseCase
    private let loadRandomWalletMode: LoadRandomWalletModeUseCase
    private let saveRandomWalletMode: SaveRandomWalletModeUseCase

    // MARK: - Initialization

    init(
        libraryService: LibraryService,
        downloadsService: DownloadsService,
        settingsService: SettingsService,
        loadPersonalWallets: LoadPersonalWalletsUseCase,
        savePersonalWallets: SavePersonalWalletsUseCase,
        loadRandomWalletMode: LoadRandomWalletModeUseCase,
        saveRandomWalletMode: SaveRandomWalletModeUseCase,
        wallets: LoadState<[Wallet]> = .idle,
        albumsByWalletID: [String: [MediaItem]] = [:]
    ) {
        self.libraryService = libraryService
        self.downloadsService = downloadsService
        self.settingsService = settingsService
        self.loadPersonalWallets = loadPersonalWallets
        self.savePersonalWallets = savePersonalWallets
        self.loadRandomWalletMode = loadRandomWalletMode
        self.saveRandomWalletMode = saveRandomWalletMode
        self.wallets = wallets
        self.albumsByWalletID = albumsByWalletID

        randomWalletMode = (try? loadRandomWalletMode()) ?? .fullyRandom
    }

    // MARK: - Public API

    func albums(for wallet: Wallet) -> [MediaItem] {
        albumsByWalletID[wallet.id] ?? []
    }

    func loadWallets() async {
        wallets = .loading

        if libraryService.libraries.isLoaded == false {
            await libraryService.loadHome()
        }

        guard let musicLibrary = libraryService.loadedLibraries.first(where: { $0.kind == .music })
        else {
            wallets = .loaded([])
            return
        }

        await ensureFullyLoaded(libraryID: musicLibrary.id)
        await downloadsService.restoreFromDisk()

        guard case let .loaded(page) = libraryService.pages[musicLibrary.id] else {
            if case let .failed(error) = libraryService.pages[musicLibrary.id] {
                wallets = .failed(error)
            }
            return
        }

        allAlbums = page.items

        var generator = SystemRandomNumberGenerator()
        let generated = GenerateAutomaticWalletsUseCase.generate(
            albums: allAlbums,
            randomMode: randomWalletMode,
            using: &generator
        )

        let libraryWallet = Wallet(
            id: "library-\(musicLibrary.id)",
            name: musicLibrary.name,
            kind: .library(id: musicLibrary.id),
            albumIDs: allAlbums.map(\.id)
        )

        let downloadedWallet = Wallet(
            id: "downloaded",
            name: "Downloaded",
            kind: .downloaded,
            albumIDs: downloadsService.downloadedAlbumIDs
        )

        let personal = (try? loadPersonalWallets()) ?? []

        wallets = .loaded([libraryWallet] + generated + [downloadedWallet] + personal)
        rebuildAlbumsByWalletID()
    }

    func createWallet(name: String) async {
        var personal = currentPersonalWallets()

        personal.append(Wallet(id: UUID().uuidString, name: name, kind: .personal))

        await applyPersonalWallets(personal)
    }

    func renameWallet(_ walletID: String, to newName: String) async {
        var personal = currentPersonalWallets()

        guard let index = personal.firstIndex(where: { $0.id == walletID }) else {
            return
        }

        personal[index] = Wallet(
            id: personal[index].id,
            name: newName,
            kind: .personal,
            albumIDs: personal[index].albumIDs
        )

        await applyPersonalWallets(personal)
    }

    func deleteWallet(_ walletID: String) async {
        var personal = currentPersonalWallets()

        personal.removeAll { $0.id == walletID }

        await applyPersonalWallets(personal)
    }

    func addAlbum(_ albumID: String, toWallet walletID: String) async {
        var personal = currentPersonalWallets()

        guard let index = personal.firstIndex(where: { $0.id == walletID }),
              personal[index].albumIDs.contains(albumID) == false
        else {
            return
        }

        personal[index] = Wallet(
            id: personal[index].id,
            name: personal[index].name,
            kind: .personal,
            albumIDs: personal[index].albumIDs + [albumID]
        )

        await applyPersonalWallets(personal)
    }

    func removeAlbum(_ albumID: String, fromWallet walletID: String) async {
        var personal = currentPersonalWallets()

        guard let index = personal.firstIndex(where: { $0.id == walletID }) else {
            return
        }

        personal[index] = Wallet(
            id: personal[index].id,
            name: personal[index].name,
            kind: .personal,
            albumIDs: personal[index].albumIDs.filter { $0 != albumID }
        )

        await applyPersonalWallets(personal)
    }

    func setRandomWalletMode(_ mode: RandomWalletMode) async {
        randomWalletMode = mode
        try? saveRandomWalletMode(mode)

        await regenerateRandomWallet()
    }

    /// Reshuffles the Random wallet's contents without touching active playback — the wallet
    /// captured the sequence it is playing at play-start, so a regenerate here never reaches it.
    func regenerateRandomWallet() async {
        guard case let .loaded(all) = wallets, allAlbums.isEmpty == false else {
            return
        }

        var generator = SystemRandomNumberGenerator()
        let generated = GenerateAutomaticWalletsUseCase.generate(
            albums: allAlbums,
            randomMode: randomWalletMode,
            using: &generator
        )

        guard let freshRandom = generated.first(where: Self.isRandomWallet) else {
            return
        }

        wallets = .loaded(all.map { Self.isRandomWallet($0) ? freshRandom : $0 })
        rebuildAlbumsByWalletID()
    }

    func endSession() {
        wallets = .idle
        allAlbums = []
        albumsByWalletID = [:]
    }

    // MARK: - Private

    private static func isRandomWallet(_ wallet: Wallet) -> Bool {
        if case .random = wallet.kind {
            return true
        }
        return false
    }

    private func ensureFullyLoaded(libraryID: String) async {
        await libraryService.loadLibrary(id: libraryID)

        while case let .loaded(page) = libraryService.pages[libraryID], page.items.count < page.totalCount {
            await libraryService.loadMore(libraryID: libraryID)
        }
    }

    private func currentPersonalWallets() -> [Wallet] {
        guard case let .loaded(all) = wallets else {
            return []
        }

        return all.filter { $0.kind == .personal }
    }

    private func applyPersonalWallets(_ personal: [Wallet]) async {
        try? savePersonalWallets(personal)

        guard case let .loaded(all) = wallets else {
            return
        }

        wallets = .loaded(all.filter { $0.kind != .personal } + personal)
        rebuildAlbumsByWalletID()
    }

    private func rebuildAlbumsByWalletID() {
        guard case let .loaded(all) = wallets else {
            return
        }

        let lookup = Dictionary(allAlbums.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        albumsByWalletID = all.reduce(into: [:]) { result, wallet in
            let resolved = wallet.albumIDs.compactMap { lookup[$0] }

            result[wallet.id] = Self.isBrowsingOrdered(wallet)
                ? Self.ordered(resolved, by: settingsService.settings.albumOrder)
                : resolved
        }
    }

    private static func isBrowsingOrdered(_ wallet: Wallet) -> Bool {
        switch wallet.kind {
        case .library,
             .personal: true
        case .genre,
             .mostPlayed,
             .random,
             .downloaded: false
        }
    }

    private static func ordered(_ albums: [MediaItem], by order: AlbumOrder) -> [MediaItem] {
        switch order {
        case .random: albums.shuffled()
        case .title: albums.sorted { $0.name < $1.name }
        case .artist: albums.sorted { ($0.albumArtist ?? "") < ($1.albumArtist ?? "") }
        }
    }
}

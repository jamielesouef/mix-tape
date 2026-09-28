//  GenerateAutomaticWalletsUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

/// Which wallets to show for a library's albums, and what belongs in each — one wallet per
/// genre present, one "Most Played" wallet, and one "Random" wallet shaped by `randomMode`.
/// Pure over its arguments so the shuffle and the least-played weighting are unit-testable
/// without a service or a live random seed.
enum GenerateAutomaticWalletsUseCase {
    static let mostPlayedLimit = 20
    static let randomWalletLimit = 20

    static func generate(
        albums: [MediaItem],
        randomMode: RandomWalletMode,
        using generator: inout some RandomNumberGenerator
    ) -> [Wallet] {
        genreWallets(albums: albums)
            + [mostPlayedWallet(albums: albums)]
            + [randomWallet(albums: albums, mode: randomMode, using: &generator)]
    }

    // MARK: - Private

    private static func genreWallets(albums: [MediaItem]) -> [Wallet] {
        let genres = Set(albums.compactMap(\.genre)).sorted()

        return genres.map { genre in
            Wallet(
                id: "genre-\(genre)",
                name: genre,
                kind: .genre(genre),
                albumIDs: albums.filter { $0.genre == genre }.map(\.id)
            )
        }
    }

    private static func mostPlayedWallet(albums: [MediaItem]) -> Wallet {
        let ids = albums
            .sorted { $0.playCount > $1.playCount }
            .prefix(mostPlayedLimit)
            .map(\.id)

        return Wallet(id: "most-played", name: "Most Played", kind: .mostPlayed, albumIDs: ids)
    }

    private static func randomWallet(
        albums: [MediaItem],
        mode: RandomWalletMode,
        using generator: inout some RandomNumberGenerator
    ) -> Wallet {
        let ids: [String] =
            switch mode {
            case .fullyRandom:
                Array(albums.shuffled(using: &generator).prefix(randomWalletLimit).map(\.id))
            case .favouringLeastPlayed:
                leastPlayedWeightedSample(albums: albums, count: randomWalletLimit, using: &generator)
            }

        return Wallet(id: "random", name: "Random", kind: .random(mode), albumIDs: ids)
    }

    /// Samples without replacement, weighting each remaining album by the inverse of its play
    /// count — an album with zero plays is far more likely to be picked than a heavily played
    /// one, but nothing is excluded outright.
    private static func leastPlayedWeightedSample(
        albums: [MediaItem],
        count: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [String] {
        var pool = albums
        var picked: [String] = []

        while picked.count < count, pool.isEmpty == false {
            let weights = pool.map { 1.0 / Double($0.playCount + 1) }
            let total = weights.reduce(0, +)
            var threshold = Double.random(in: 0 ..< total, using: &generator)

            var chosenIndex = pool.indices.last! // Unreachable: the while-loop guard keeps pool non-empty.

            for index in pool.indices {
                threshold -= weights[index]

                if threshold <= 0 {
                    chosenIndex = index
                    break
                }
            }

            picked.append(pool[chosenIndex].id)
            pool.remove(at: chosenIndex)
        }

        return picked
    }
}

//  OperationGeneration.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

/// Identifies one playback operation (`play`/`start`/`stop`) so a stale controller callback,
/// resolution completion, or progress tick from an earlier operation can never mutate state a
/// newer operation owns. Named for what it guards, not the player, so a later slice can reuse it
/// on `LibraryService.refresh()` without the name implying playback (slice 021 decision log).
struct OperationGeneration: Equatable {
    private let id = UUID()
}

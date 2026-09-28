//  NetworkPathMonitor.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import Network

/// The one place the app reads live connectivity — whether a path exists at all, and
/// whether it is Wi-Fi. `DownloadsService` reads `isWiFi` to gate Wi-Fi-only downloads;
/// `SearchService` reads `isConnected` to limit search to downloaded music while offline.
actor NetworkPathMonitor {
    struct Status: Sendable, Equatable {
        let isConnected: Bool
        let isWiFi: Bool

        static let assumedConnected = Status(isConnected: true, isWiFi: true)
    }

    private let monitor: NWPathMonitor
    private var current: Status

    init() {
        monitor = NWPathMonitor()
        current = .assumedConnected

        let box = MonitorBox(monitor)

        box.observe { [weak self] status in
            Task { await self?.update(status) }
        }
    }

    func status() -> Status {
        current
    }

    // MARK: - Private

    private func update(_ status: Status) {
        current = status
    }
}

/// Bridges `NWPathMonitor`'s non-Sendable callback onto the actor without capturing it
/// directly in a `Sendable` closure context.
private final class MonitorBox {
    private let monitor: NWPathMonitor

    init(_ monitor: NWPathMonitor) {
        self.monitor = monitor
    }

    func observe(_ handler: @escaping @Sendable (NetworkPathMonitor.Status) -> Void) {
        monitor.pathUpdateHandler = { path in
            handler(NetworkPathMonitor.Status(
                isConnected: path.status == .satisfied,
                isWiFi: path.usesInterfaceType(.wifi)
            ))
        }
        monitor.start(queue: DispatchQueue(label: "mobi.jamie.mixtape.network"))
    }
}

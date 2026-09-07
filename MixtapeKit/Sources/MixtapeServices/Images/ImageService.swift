//  ImageService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeUseCase
import Observation
import UIKit

/// Engineering doc §6: URL building plus an in-memory `NSCache` capped at 120 MB. Image requests
/// carry no auth (decision 25), so this needs nothing from Infrastructure. Decoding is the one
/// `@concurrent` hop in the browse path.
@Observable
public final class ImageService {
    public static let cacheLimitBytes = 120 * 1024 * 1024

    private let builder: any ImageURLBuilderProtocol
    private let sessionService: SessionService
    private let urlSession: URLSession
    @ObservationIgnored private let cache = NSCache<NSURL, UIImage>()
    @ObservationIgnored private var inFlightRequests: [URL: Task<UIImage?, Never>] = [:]

    public init(builder: any ImageURLBuilderProtocol, sessionService: SessionService, urlSession: URLSession = .shared) {
        self.builder = builder
        self.sessionService = sessionService
        self.urlSession = urlSession
        cache.totalCostLimit = Self.cacheLimitBytes
    }

    /// Tracks have no art of their own: `.primary` falls back to the album (decision 25).
    public func imageURL(for item: MediaItem, kind: ImageKind, maxHeight: Int) -> URL? {
        guard let session else { return nil }
        if kind == .primary, item.kind == .audio, item.primaryImageTag == nil, let albumID = item.albumID {
            return builder.url(itemID: albumID, tag: item.parentPrimaryImageTag, kind: .primary, maxHeight: maxHeight, session: session)
        }
        let tag = kind == .primary ? item.primaryImageTag : item.backdropImageTag
        return builder.url(itemID: item.id, tag: tag, kind: kind, maxHeight: maxHeight, session: session)
    }

    public func imageURL(for library: Library, maxHeight: Int) -> URL? {
        guard let session else { return nil }
        return builder.url(itemID: library.id, tag: library.imageTag, kind: .primary, maxHeight: maxHeight, session: session)
    }

    public func image(for item: MediaItem, kind: ImageKind, maxHeight: Int) async -> UIImage? {
        await image(at: imageURL(for: item, kind: kind, maxHeight: maxHeight))
    }

    public func image(for library: Library, maxHeight: Int) async -> UIImage? {
        await image(at: imageURL(for: library, maxHeight: maxHeight))
    }

    public func image(at url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        if let inFlight = inFlightRequests[url] {
            return await inFlight.value
        }
        let task = Task { [weak self] in
            await self?.fetch(url)
        }
        inFlightRequests[url] = task
        defer { inFlightRequests[url] = nil }
        return await task.value
    }

    private func fetch(_ url: URL) async -> UIImage? {
        guard let (data, response) = try? await urlSession.data(from: url),
              let http = response as? HTTPURLResponse,
              (200 ... 299).contains(http.statusCode),
              let image = await Self.decode(data)
        else { return nil }
        cache.setObject(image, forKey: url as NSURL, cost: Self.cost(of: image))
        return image
    }

    /// Cost from the *decoded* pixel dimensions, not the compressed network byte count — a small
    /// JPEG can decode to a large bitmap, and `NSCache`'s eviction only makes sense against the
    /// memory the image actually occupies.
    static func cost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else {
            return Int(image.size.width * image.scale * image.size.height * image.scale) * 4
        }
        return cgImage.width * cgImage.height * 4
    }

    @concurrent
    private nonisolated static func decode(_ data: Data) async -> UIImage? {
        UIImage(data: data)?.preparingForDisplay()
    }

    private var session: UserSession? {
        if case let .signedIn(session) = sessionService.state {
            return session
        }
        return nil
    }
}

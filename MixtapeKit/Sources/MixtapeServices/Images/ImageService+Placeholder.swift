//  ImageService+Placeholder.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public extension ImageService {
    /// `@Entry` default. Never used by a running app — the composition root always injects one.
    /// Debug builds use the preview mock; release builds, which carry no `Mock*` type (slice 013),
    /// build the same service over the inert `Placeholder*` collaborators.
    static let placeholder: ImageService = {
        #if DEBUG
            return MockImageService.make()
        #else
            return ImageService(builder: PlaceholderImageURLBuilder(), sessionService: .placeholder)
        #endif
    }()
}

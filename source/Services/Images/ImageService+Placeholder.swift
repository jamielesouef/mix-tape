//  ImageService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public extension ImageService {
    static let placeholder: ImageService = {
        #if DEBUG
            return MockImageService.make()
        #else
            return ImageService(builder: PlaceholderImageURLBuilder(), sessionService: .placeholder)
        #endif
    }()
}

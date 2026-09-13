//  RemoteImage.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

struct RemoteImage: View {
    enum Source: Hashable {
        case item(MediaItem, ImageKind)
        case library(Library)
    }

    @Environment(\.imageService) private var imageService
    @State private var image: UIImage?
    let source: Source
    let maxHeight: Int
    var placeholder = "photo"

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: placeholder)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: source) {
            image = switch source {
            case let .item(item, kind): await imageService.image(for: item, kind: kind, maxHeight: maxHeight)
            case let .library(library): await imageService.image(for: library, maxHeight: maxHeight)
            }
        }
    }
}

#if DEBUG
    #Preview("loaded") {
        RemoteImage(source: .item(MockMedia.movies[0], .primary), maxHeight: 300)
            .frame(width: 200, height: 300)
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        RemoteImage(source: .library(MockMedia.libraries[3]), maxHeight: 300, placeholder: "books.vertical")
            .frame(width: 200, height: 200)
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("failure") {
        RemoteImage(source: .item(MockMedia.movies[0], .backdrop), maxHeight: 300)
            .frame(width: 320, height: 180)
            .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
    }
#endif

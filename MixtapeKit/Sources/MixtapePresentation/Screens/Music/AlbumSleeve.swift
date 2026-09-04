//  AlbumSleeve.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// One album in a clear plastic sleeve (engineering doc §9.1): art inset in a rounded rect with a
    /// thin border and a single diagonal specular highlight. `nil` is an empty sleeve on a partial
    /// page. Under Reduce Transparency the sheen goes and it is a flat bordered card. The highlight
    /// is static — the tilt-following sheen is cut (slice 010 decision log), so Reduce Motion has
    /// nothing left to switch off.
    struct AlbumSleeve: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        let album: MediaItem?
        var isPulsing = false

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                if let album {
                    RemoteImage(source: .item(album, .primary), maxHeight: 450, placeholder: "music.note")
                        .clipShape(.rect(cornerRadius: 8))
                        .padding(6)
                }
                if reduceTransparency == false {
                    LinearGradient(
                        colors: [.white.opacity(0.45), .white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.6, y: 0.65),
                    )
                    .allowsHitTesting(false)
                }
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isPulsing ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: isPulsing ? 4 : 1)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityLabel(album?.displayTitle ?? "Empty sleeve")
        }
    }

    #Preview("loaded") {
        AlbumSleeve(album: MockMedia.albums[0])
            .frame(width: 160)
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        AlbumSleeve(album: nil)
            .frame(width: 160)
    }

    #Preview("failure") {
        AlbumSleeve(album: MockMedia.albums[1], isPulsing: true)
            .frame(width: 160)
            .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
    }
#endif

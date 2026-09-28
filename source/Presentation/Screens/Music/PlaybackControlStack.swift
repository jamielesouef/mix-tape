//  PlaybackControlStack.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

/// The primary playback controls, stacked vertically for one-handed use. Lives at the
/// bottom-right of Album Detail, visually separate from the mini player's information about
/// what is currently playing.
struct PlaybackControlStack: View {
    // MARK: - Properties

    @Environment(\.musicPlayerService) private var music: MusicPlayerService
    let album: MediaItem
    let sequence: [MediaItem]
    let tracks: [MediaItem]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            if music.isActive {
                Button { Task { await music.stop() } } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title)
                }
                .accessibilityLabel("Stop")
                .accessibilityIdentifier(AlbumDetailIdentifiers.stopButton)
            }

            primaryButton
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .shadow(radius: 4)
    }

    // MARK: - Private

    private var action: AlbumPlaybackAction {
        AlbumPlaybackAction.resolve(
            displayedAlbumID: album.id,
            playingAlbumID: music.album?.id,
            isActive: music.isActive
        )
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch action {
        case .play:
            Button { play() } label: {
                Image(systemName: "play.circle.fill").font(.largeTitle)
            }
            .disabled(tracks.isEmpty)
            .accessibilityLabel("Play")
            .accessibilityIdentifier(AlbumDetailIdentifiers.playButton)

        case .playPause:
            Button { music.togglePlayPause() } label: {
                Image(systemName: music.status == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.largeTitle)
            }
            .accessibilityLabel(music.status == .playing ? "Pause" : "Play")
            .accessibilityIdentifier(AlbumDetailIdentifiers.playPauseButton)

        case .playReplace:
            Button { play() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill").font(.largeTitle)
            }
            .disabled(tracks.isEmpty)
            .accessibilityLabel("Play and replace what's currently playing with this album")
            .accessibilityIdentifier(AlbumDetailIdentifiers.playReplaceButton)
        }
    }

    private func play() {
        guard tracks.isEmpty == false else {
            return
        }

        Task { await music.play(album: album, tracks: tracks, startingAt: 0, sequence: sequence) }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        PlaybackControlStack(
            album: MockMedia.albums[0],
            sequence: [MockMedia.albums[1]],
            tracks: MockMedia.tracks
        )
        .padding()
        .background(.black)
        .environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }

    #Preview("empty") {
        PlaybackControlStack(album: MockMedia.albums[0], sequence: [], tracks: [])
            .padding()
            .background(.black)
            .environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }

    #Preview("failure") {
        PlaybackControlStack(
            album: MockMedia.albums[1],
            sequence: [],
            tracks: MockMedia.tracks
        )
        .padding()
        .background(.black)
        .environment(\.musicPlayerService, MockMusicPlayerService.playing())
    }
#endif

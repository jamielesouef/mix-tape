//  VLCVideoSurface.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS) || os(tvOS)
    import SwiftUI
    import UIKit

    /// libVLC renders into any `UIView` set as the player's `drawable` (the public `VLCVideoView`
    /// is only forward-declared), so this wraps a plain `UIView` for SwiftUI.
    struct VLCVideoSurface: UIViewRepresentable {
        let videoView: UIView

        func makeUIView(context _: Context) -> UIView {
            videoView
        }

        func updateUIView(_: UIView, context _: Context) {}
    }
#endif

//  VLCVideoSurface.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS) || os(tvOS)
    import SwiftUI
    import UIKit

    struct VLCVideoSurface: UIViewRepresentable {
        let videoView: UIView

        func makeUIView(context _: Context) -> UIView {
            videoView
        }

        func updateUIView(_: UIView, context _: Context) {}
    }
#endif

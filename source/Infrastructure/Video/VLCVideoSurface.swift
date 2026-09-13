//  VLCVideoSurface.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import SwiftUI
import UIKit

struct VLCVideoSurface: UIViewRepresentable {
    let videoView: UIView

    func makeUIView(context _: Context) -> UIView {
        videoView
    }

    func updateUIView(_: UIView, context _: Context) {}
}

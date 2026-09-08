//  LibraryKindListScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 05/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// The root of a tvOS kind tab when the user has more than one library of that kind (§1.5, slice
    /// 016): every library, as a focusable row that pushes its shelf. With a single library the tab
    /// hosts the shelf directly and this screen never appears.
    struct LibraryKindListScreen: View {
        let libraries: [Library]

        var body: some View {
            List(libraries) { library in
                NavigationLink(value: library) {
                    HStack(spacing: 24) {
                        RemoteImage(source: .library(library), maxHeight: 180, placeholder: "books.vertical")
                            .frame(width: 192, height: 108)
                            .clipShape(.rect(cornerRadius: 12))
                        Text(library.name)
                            .font(.headline)
                    }
                }
                .accessibilityIdentifier(LibraryTabIdentifiers.libraryRow(library.id))
            }
            .accessibilityIdentifier(LibraryTabIdentifiers.libraryList)
        }
    }

    #if DEBUG
        #Preview("loaded") {
            NavigationStack {
                LibraryKindListScreen(libraries: [
                    MockMedia.libraries[2],
                    Library(id: "lib-music-2", name: "Music 2", kind: .music, imageTag: nil),
                ])
            }
            .environment(\.imageService, MockImageService.make())
        }

        #Preview("empty") {
            NavigationStack {
                LibraryKindListScreen(libraries: [])
            }
        }

        #Preview("failure") {
            NavigationStack {
                LibraryKindListScreen(libraries: [MockMedia.libraries[2]])
            }
            .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
        }
    #endif
#endif

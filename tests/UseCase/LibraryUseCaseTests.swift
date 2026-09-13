//  LibraryUseCaseTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.useCase))
struct LibraryUseCaseTests {
    private let session = MockAuthRepository.sampleSession

    @Test func `fetch libraries filters unsupported`() async throws {
        let libraries = try await FetchLibrariesUseCase(repository: MockLibraryRepository())(session: session)
        #expect(libraries.map(\.kind) == [.music])
    }

    @Test func `fetch library items passes library kind and page through`() async throws {
        let recorder = Recorder()
        let repository = MockLibraryRepository(itemsResult: { id, kind, page, _ in
            recorder.append("\(id) \(kind) \(page.startIndex) \(page.limit)")
            return Page(items: [], totalCount: 0, startIndex: page.startIndex)
        })
        let page = try await FetchLibraryItemsUseCase(repository: repository)(
            libraryID: "lib", kind: .musicAlbum, page: PageRequest(startIndex: 60, limit: 60), session: session,
        )
        #expect(page.startIndex == 60)
        #expect(recorder.urls == ["lib musicAlbum 60 60"])
    }

    @Test func `fetch item detail returns the item`() async throws {
        let item = try await FetchItemDetailUseCase(repository: MockLibraryRepository())(id: "album-1", session: session)
        #expect(item.id == "album-1")
    }

    @Test func `fetch album tracks passes the album id`() async throws {
        let recorder = Recorder()
        let repository = MockLibraryRepository(tracksResult: { id, _ in
            recorder.append(id)
            return MockLibraryRepository.sampleTracks
        })
        let tracks = try await FetchAlbumTracksUseCase(repository: repository)(albumID: "album-1", session: session)
        #expect(tracks.count == 2)
        #expect(recorder.urls == ["album-1"])
    }

    @Test(arguments: [MixtapeError.sessionExpired, .serverUnreachable])
    func `repository errors propagate unchanged`(error: MixtapeError) async {
        let repository = MockLibraryRepository(
            librariesResult: { _ in throw error },
            itemsResult: { _, _, _, _ in throw error },
        )
        await #expect(throws: error) { try await FetchLibrariesUseCase(repository: repository)(session: session) }
        await #expect(throws: error) {
            try await FetchLibraryItemsUseCase(repository: repository)(
                libraryID: "lib", kind: .musicAlbum, page: PageRequest(startIndex: 0, limit: 60), session: session,
            )
        }
    }
}

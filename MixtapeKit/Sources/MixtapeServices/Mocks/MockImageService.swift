//  MockImageService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG
    import MixtapeUseCase

    /// A real `ImageService` over `MockImageURLBuilder`: `mock://` URLs never load, so previews show
    /// the placeholder art without touching a server.
    public enum MockImageService {
        public static func make(sessionService: SessionService = MockSessionService.signedIn()) -> ImageService {
            ImageService(builder: MockImageURLBuilder(), sessionService: sessionService)
        }
    }
#endif

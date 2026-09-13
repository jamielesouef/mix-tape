//  MockImageService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG
    import MixtapeUseCase

    public enum MockImageService {
        public static func make(sessionService: SessionService = MockSessionService.signedIn()) -> ImageService {
            ImageService(builder: MockImageURLBuilder(), sessionService: sessionService)
        }
    }
#endif

//  MockImageService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG

    enum MockImageService {
        static func make(sessionService: SessionService = MockSessionService.signedIn()) -> ImageService {
            ImageService(builder: MockImageURLBuilder(), sessionService: sessionService)
        }
    }
#endif

//  StoredSessionDTO.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

nonisolated struct StoredSessionDTO: Codable {
    let serverURL: URL
    let userID: String
    let userName: String
    let accessToken: String
    let deviceID: String

    init(_ session: UserSession) {
        serverURL = session.serverURL
        userID = session.userID
        userName = session.userName
        accessToken = session.accessToken
        deviceID = session.deviceID
    }

    var session: UserSession {
        UserSession(serverURL: serverURL, userID: userID, userName: userName, accessToken: accessToken, deviceID: deviceID)
    }
}

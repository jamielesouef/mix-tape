// SPDX-License-Identifier: MIT
//
//  VersionScreenUITests.swift
//  MixTapeUITests
//
//  Created by Jamie Le Souëf on 01/09/2026.
//

import XCTest

final class VersionScreenUITests: XCTestCase {
  @MainActor
  func testVersionScreenReachesSettledState() {
    let app = XCUIApplication()
    app.launch()

    let serverVersion = app.staticTexts["versionScreen.serverVersion"]
    let error = app.staticTexts["versionScreen.error"]

    let settled = serverVersion.waitForExistence(timeout: 10) || error.waitForExistence(timeout: 10)
    XCTAssertTrue(settled, "Version screen never reached a settled state")

    if serverVersion.exists {
      XCTAssertFalse(serverVersion.label.isEmpty, "Server version label was empty")
    }
  }
}

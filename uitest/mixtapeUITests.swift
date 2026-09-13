//
//  mixtapeUITests.swift
//  mixtapeUITests
//
//  Created by Jamie Le Souef on 3/9/2026.
//

import XCTest

final class mixtapeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    func testExample() {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

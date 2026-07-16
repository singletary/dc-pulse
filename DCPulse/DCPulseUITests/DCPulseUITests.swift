//
//  DCPulseUITests.swift
//  DCPulseUITests
//
//  Created by Michael Singletary on 7/11/26.
//

import XCTest

final class DCPulseUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Keep feature tests deterministic even if a launch test previously left
        // the shared simulator in landscape.
        XCUIDevice.shared.orientation = .portrait

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Happening near you"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMapTabShowsClusteredMapAndControls() throws {
        let app = XCUIApplication()
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10))
        mapTab.tap()

        XCTAssertTrue(app.otherElements["map.clustered"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["map.filter"].exists)
        XCTAssertTrue(app.buttons["map.currentLocation"].exists)

        app.buttons["map.filter"].tap()
        let radiusMenu = app.buttons["map.filter.radius"]
        XCTAssertTrue(radiusMenu.waitForExistence(timeout: 5))
        radiusMenu.tap()
        XCTAssertTrue(app.buttons["0.25 mile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["0.5 mile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["1 mile"].waitForExistence(timeout: 5))
        app.buttons["0.25 mile"].tap()
        let reset = app.buttons["map.filters.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        XCTAssertTrue(reset.isEnabled)
        reset.tap()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Clustered Map"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testStatusListOpensItemAndReturnsDirectlyHome() throws {
        let app = XCUIApplication()
        app.launch()

        let newStatus = app.buttons["pulse.status.new"]
        XCTAssertTrue(newStatus.waitForExistence(timeout: 15))
        newStatus.tap()
        XCTAssertTrue(app.navigationBars["New"].waitForExistence(timeout: 10))

        let firstItem = app.buttons.matching(identifier: "status.item").firstMatch
        XCTAssertTrue(firstItem.waitForExistence(timeout: 15))
        firstItem.tap()
        XCTAssertTrue(app.navigationBars["Item Details"].waitForExistence(timeout: 10))

        app.navigationBars["Item Details"].buttons["New"].tap()
        XCTAssertTrue(app.navigationBars["New"].waitForExistence(timeout: 10))
        app.navigationBars["New"].buttons["Happening near you"].tap()
        XCTAssertTrue(app.navigationBars["Happening near you"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testRequestsTabExposesFollowedLocationBrowser() throws {
        let app = XCUIApplication()
        app.launch()

        let requestsTab = app.tabBars.buttons["Requests"]
        XCTAssertTrue(requestsTab.waitForExistence(timeout: 10))
        requestsTab.tap()
        XCTAssertTrue(app.buttons["requests.locationPicker"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testNotificationCenterOpensFromNearYou() throws {
        let app = XCUIApplication()
        app.launch()

        let notifications = app.buttons["pulse.notifications"]
        XCTAssertTrue(notifications.waitForExistence(timeout: 10))
        notifications.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No notifications yet"].exists)
    }

    @MainActor
    func testCivicActionDestinationsOpenFromNearYou() throws {
        let app = XCUIApplication()
        app.launch()

        let reportButton = app.buttons["pulse.report311"]
        scrollToElement(reportButton, in: app)
        reportButton.tap()
        XCTAssertTrue(app.navigationBars["Report to 311"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Start with a photo"].exists)
        XCTAssertTrue(app.buttons["report311.choosePhoto"].exists)
        XCTAssertTrue(app.buttons["report311.takePhoto"].exists)

        let details = app.textFields["report311.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.tap()
        details.typeText("Test request details")
        let continueButton = app.buttons["report311.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertTrue(continueButton.isHittable)
        continueButton.tap()
        XCTAssertTrue(app.alerts["Draft copied"].waitForExistence(timeout: 5))
        app.alerts["Draft copied"].buttons["Cancel"].tap()

        app.navigationBars["Report to 311"].buttons["Happening near you"].tap()
        let healthButton = app.buttons["pulse.restaurantHealth"]
        scrollToElement(healthButton, in: app)
        healthButton.tap()
        XCTAssertTrue(app.navigationBars["Restaurant Health"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Check before you dine"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
    }
}

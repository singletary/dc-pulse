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
        XCTAssertTrue(app.navigationBars["Near You"].waitForExistence(timeout: 10))
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
        let quarterMile = app.buttons["map.radius.0.25"]
        let halfMile = app.buttons["map.radius.0.5"]
        let oneMile = app.buttons["map.radius.1.0"]
        XCTAssertTrue(quarterMile.waitForExistence(timeout: 5))
        XCTAssertTrue(halfMile.waitForExistence(timeout: 5))
        XCTAssertTrue(oneMile.waitForExistence(timeout: 5))
        XCTAssertEqual(quarterMile.label, "quarter-mile radius")
        XCTAssertEqual(halfMile.label, "half-mile radius")
        XCTAssertEqual(oneMile.label, "one-mile radius")
        quarterMile.tap()
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
    func testStatusSelectionRefreshesInsightsAndTogglesBackToAll() throws {
        let app = XCUIApplication()
        app.launch()

        let newStatus = app.buttons["pulse.status.new"]
        XCTAssertTrue(newStatus.waitForExistence(timeout: 15))
        newStatus.tap()
        let selected = NSPredicate(format: "value CONTAINS[c] %@", "selected")
        expectation(for: selected, evaluatedWith: newStatus)
        waitForExpectations(timeout: 10)

        XCTAssertFalse(app.buttons["pulse.status.viewList"].exists)
        XCTAssertFalse(app.buttons["pulse.status.all"].exists)
        newStatus.tap()
        let notSelected = NSPredicate(format: "value CONTAINS[c] %@", "not selected")
        expectation(for: notSelected, evaluatedWith: newStatus)
        waitForExpectations(timeout: 5)
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
    func testNeighborhoodSummaryOpensFromNearYou() throws {
        let app = XCUIApplication()
        app.launch()

        let summary = app.buttons["pulse.neighborhoodSummary"]
        scrollToElement(summary, in: app)
        summary.tap()

        XCTAssertTrue(app.navigationBars["Neighborhood Summary"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["neighborhoodSummary.statusScope"].exists)
    }

    @MainActor
    func testAboutOpensFromPlacesWithTrustInformation() throws {
        let app = XCUIApplication()
        app.launch()

        let placesTab = app.tabBars.buttons["Places"]
        XCTAssertTrue(placesTab.waitForExistence(timeout: 10))
        placesTab.tap()
        let about = app.buttons["places.about"]
        XCTAssertTrue(about.waitForExistence(timeout: 10))
        about.tap()

        XCTAssertTrue(app.navigationBars["About DC Pulse"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["DC Pulse"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["about.website"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["about.privacy"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["about.source-code"].exists)
    }

    @MainActor
    func testArchivedWatchCanBeRestoredAndSurvivesRelaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DCPULSE_UI_TEST_SCENARIO"] = "watch-restoration"
        app.launch()

        openPlaces(in: app)
        let archivedWatch = app.buttons["places.watch.archived"]
        scrollToElement(archivedWatch, in: app)
        archivedWatch.swipeLeft()
        let restore = app.buttons["places.watch.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(app.buttons["places.watch.active"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "DCPULSE_UI_TEST_SCENARIO")
        app.launch()

        openPlaces(in: app)
        XCTAssertTrue(app.buttons["places.watch.active"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["places.watch.archived"].exists)
    }

    @MainActor
    func testFollowedPlaceSelectionOpensItsMapContext() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DCPULSE_UI_TEST_SCENARIO"] = "followed-place-navigation"
        app.launch()

        openPlaces(in: app)
        let savedPlace = app.buttons["places.savedPlace"]
        scrollToElement(savedPlace, in: app)
        XCTAssertEqual(savedPlace.value as? String, "Synthetic saved place, Washington, DC")
        savedPlace.tap()

        XCTAssertTrue(app.tabBars.buttons["Map"].isSelected)
        XCTAssertTrue(app.navigationBars["Map"].waitForExistence(timeout: 10))
        let map = app.otherElements["map.clustered"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        let selectedContext = NSPredicate(format: "value == %@", "Synthetic saved place, Washington, DC")
        expectation(for: selectedContext, evaluatedWith: map)
        waitForExpectations(timeout: 10)
    }

    @MainActor
    func testCityServicesRemainHiddenFromNearYou() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Near You"].waitForExistence(timeout: 10))
        for _ in 0..<8 { app.swipeUp() }
        XCTAssertFalse(app.buttons["pulse.report311"].exists)
        XCTAssertFalse(app.buttons["pulse.restaurantHealth"].exists)
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

    private func openPlaces(in app: XCUIApplication) {
        let placesTab = app.tabBars.buttons["Places"]
        XCTAssertTrue(placesTab.waitForExistence(timeout: 10))
        placesTab.tap()
        XCTAssertTrue(app.navigationBars["Places"].waitForExistence(timeout: 10))
    }
}

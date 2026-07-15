import Foundation
import Testing
@testable import DCPulse

@MainActor
struct InAppNotificationTests {
    @Test func statusChangeRetainsItemAndReadState() throws {
        let item = try #require(SampleData.items.first)
        let notification = InAppNotification.statusChange(
            item: item,
            previousStatus: .new,
            changedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(notification.kind == .statusChanged)
        #expect(notification.item == item)
        #expect(notification.isUnread)
        #expect(notification.title.contains(item.category))

        notification.markRead(at: Date(timeIntervalSince1970: 1_700_000_100))
        #expect(!notification.isUnread)
    }

    @Test func eventKeysDeduplicateEquivalentEvents() throws {
        let item = try #require(SampleData.items.first)
        let firstStatus = InAppNotification.statusChange(item: item, previousStatus: .new)
        let secondStatus = InAppNotification.statusChange(item: item, previousStatus: .new)
        let firstNearby = InAppNotification.newNearbyItem(item: item)
        let secondNearby = InAppNotification.newNearbyItem(item: item)

        #expect(firstStatus.eventKey == secondStatus.eventKey)
        #expect(firstNearby.eventKey == secondNearby.eventKey)
        #expect(firstStatus.eventKey != firstNearby.eventKey)
    }
}

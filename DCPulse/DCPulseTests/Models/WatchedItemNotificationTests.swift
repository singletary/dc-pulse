import Foundation
import Testing
import UserNotifications
@testable import DCPulse

@MainActor
struct WatchedItemNotificationTests {
    @Test func buildsSourceSpecificStatusChangeNotification() throws {
        let item = PulseItem(
            id: .init(source: .serviceRequests311, sourceIdentifier: "311-42"),
            category: "Graffiti Removal", subtype: nil, title: "Graffiti request", summary: nil,
            status: .resolved, openedAt: .now, updatedAt: .now, closedAt: .now,
            coordinate: PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300),
            address: "9999 Example Avenue NW", wardOrNeighborhood: "Ward 1",
            responsibleAgency: "DPW", sourceAttributes: [], sourceURL: nil
        )

        let request = WatchedItemNotification.request(
            item: item,
            previousStatus: .active,
            changedAt: Date(timeIntervalSince1970: 100)
        )

        #expect(request.content.title == "Status changed · Graffiti Removal")
        #expect(request.content.body == "Active → Resolved")
        #expect(!request.content.body.contains("9999 Example Avenue NW"))
        #expect(request.content.userInfo["sourceIdentifier"] as? String == "311-42")
        #expect(request.trigger == nil)
    }

    @Test func mapsSystemAuthorizationStates() {
        #expect(NotificationService.state(for: .notDetermined) == .notDetermined)
        #expect(NotificationService.state(for: .denied) == .denied)
        #expect(NotificationService.state(for: .authorized) == .authorized)
        #expect(NotificationService.state(for: .provisional) == .authorized)
    }
}

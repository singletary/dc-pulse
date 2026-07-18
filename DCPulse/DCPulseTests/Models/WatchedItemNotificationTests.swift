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

    @Test func buildsPrivacySafeNewNearbyNotification() throws {
        let item = PulseItem(
            id: .init(source: .buildingPermits2026, sourceIdentifier: "B2601234"),
            category: "Building Permit", subtype: "Fence", title: "Fence permit", summary: nil,
            status: .active, openedAt: .now, updatedAt: .now, closedAt: nil,
            coordinate: PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300),
            address: "9999 Example Avenue NW", wardOrNeighborhood: "Ward 1",
            responsibleAgency: "DOB", sourceAttributes: [], sourceURL: nil
        )

        let request = NewNearbyItemNotification.request(
            item: item,
            discoveredAt: Date(timeIntervalSince1970: 100)
        )

        #expect(request.content.title == "New near Home · Building Permit")
        #expect(!request.content.body.contains("9999 Example Avenue NW"))
        #expect(request.content.userInfo["sourceIdentifier"] as? String == "B2601234")
        #expect(request.trigger == nil)
    }

    @Test func persistsIndependentAlertPreferencesAndMigratesLegacyChoice() throws {
        let suite = "NotificationServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "dcPulse.notifications.watchedItemsEnabled")

        let migrated = NotificationService(defaults: defaults)
        #expect(migrated.statusChangeAlertsEnabled)
        #expect(migrated.newNearbyAlertsEnabled)

        migrated.statusChangeAlertsEnabled = false
        migrated.newNearbyAlertsEnabled = true
        let restored = NotificationService(defaults: defaults)
        #expect(!restored.statusChangeAlertsEnabled)
        #expect(restored.newNearbyAlertsEnabled)
    }
}

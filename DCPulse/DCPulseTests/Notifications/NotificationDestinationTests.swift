import Testing
@testable import DCPulse

@MainActor
struct NotificationDestinationTests {
    @Test func parsesSourceNamespacedItemIdentity() throws {
        let destination = try #require(NotificationDestination(userInfo: [
            "source": PulseItem.Source.buildingPermits2026.rawValue,
            "sourceIdentifier": "B2601234"
        ]))

        #expect(destination.itemID == .init(source: .buildingPermits2026, sourceIdentifier: "B2601234"))
    }

    @Test func rejectsMalformedPayloads() {
        #expect(NotificationDestination(userInfo: ["source": "unknown", "sourceIdentifier": "1"]) == nil)
        #expect(NotificationDestination(userInfo: ["source": PulseItem.Source.serviceRequests311.rawValue]) == nil)
    }
}

import Foundation
import Testing
@testable import DCPulse

@MainActor
struct PulseObservationRecordTests {
    @Test func updatesMutableSnapshotWithoutChangingIdentityOrFirstSeenDate() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let firstSeen = Date(timeIntervalSince1970: 100)
        let active = item(status: .active, coordinate: coordinate)
        let record = PulseObservationRecord(item: active, observedAt: firstSeen)

        record.update(from: item(status: .resolved, coordinate: coordinate), observedAt: firstSeen.addingTimeInterval(60))

        #expect(record.stableKey == WatchedPulseItem.stableKey(for: active.id))
        #expect(record.firstObservedAt == firstSeen)
        #expect(record.lastObservedAt == firstSeen.addingTimeInterval(60))
        #expect(record.observation.status == .resolved)
    }

    private func item(status: PulseItem.Status, coordinate: PulseItem.Coordinate) -> PulseItem {
        PulseItem(
            id: .init(source: .serviceRequests311, sourceIdentifier: "311-1"),
            category: "Rodent Inspection", subtype: nil, title: "Rodent request", summary: nil,
            status: status, openedAt: Date(timeIntervalSince1970: 50), updatedAt: nil,
            closedAt: nil, coordinate: coordinate, address: nil, wardOrNeighborhood: nil,
            responsibleAgency: nil, sourceAttributes: [], sourceURL: nil
        )
    }
}

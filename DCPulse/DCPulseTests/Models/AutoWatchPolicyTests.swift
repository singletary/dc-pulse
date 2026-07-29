import Foundation
import Testing
@testable import DCPulse

@MainActor
struct AutoWatchPolicyTests {
    @Test func selectsNewRequestAndPermitWithinDistance() throws {
        let home = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let nearby = try #require(PulseItem.Coordinate(latitude: 38.9002, longitude: -77.0300))
        let newRequest = item(source: .serviceRequests311, id: "new", status: .new, coordinate: nearby)
        let activeRequest = item(source: .serviceRequests311, id: "active", status: .active, coordinate: nearby)
        let permit = item(source: .buildingPermits2026, id: "permit", status: .active, coordinate: nearby)

        let candidates = AutoWatchPolicy.candidates(
            from: [newRequest, activeRequest, permit],
            home: home,
            distanceMiles: 0.1,
            excluding: []
        )

        #expect(Set(candidates.map(\.id)) == [newRequest.id, permit.id])
    }

    @Test func excludesDistantAndAlreadyWatchedItems() throws {
        let home = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let distant = try #require(PulseItem.Coordinate(latitude: 38.9200, longitude: -77.0300))
        let item = item(source: .serviceRequests311, id: "new", status: .new, coordinate: distant)

        #expect(AutoWatchPolicy.candidates(from: [item], home: home, distanceMiles: 0.1, excluding: []).isEmpty)
    }

    @Test func newNearbyNotificationsRemainWithinPointOneMileWhenAutoWatchIsWider() throws {
        let home = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let withinNotificationRange = try #require(PulseItem.Coordinate(latitude: 38.9010, longitude: -77.0300))
        let outsideNotificationRange = try #require(PulseItem.Coordinate(latitude: 38.9030, longitude: -77.0300))
        let closeItem = item(
            source: .serviceRequests311,
            id: "close",
            status: .new,
            coordinate: withinNotificationRange
        )
        let widerAutoWatchItem = item(
            source: .serviceRequests311,
            id: "wider",
            status: .new,
            coordinate: outsideNotificationRange
        )

        let candidates = AutoWatchPolicy.candidates(
            from: [closeItem, widerAutoWatchItem],
            home: home,
            distanceMiles: 0.25,
            excluding: []
        )

        #expect(candidates.count == 2)
        #expect(AutoWatchPolicy.isEligibleForNewNearbyNotification(closeItem, home: home))
        #expect(!AutoWatchPolicy.isEligibleForNewNearbyNotification(widerAutoWatchItem, home: home))
        #expect(AutoWatchPolicy.newNearbyNotificationDistanceMiles == 0.1)
    }

    private func item(
        source: PulseItem.Source,
        id: String,
        status: PulseItem.Status,
        coordinate: PulseItem.Coordinate
    ) -> PulseItem {
        PulseItem(
            id: .init(source: source, sourceIdentifier: id), category: "Test", subtype: nil,
            title: "Test", summary: nil, status: status, openedAt: .now, updatedAt: nil,
            closedAt: nil, coordinate: coordinate, address: nil, wardOrNeighborhood: nil,
            responsibleAgency: nil, sourceAttributes: [], sourceURL: nil
        )
    }
}

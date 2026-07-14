import Foundation
import Testing
@testable import DCPulse

@MainActor
struct NoteworthyItemRankerTests {
    @Test func nearbyHomePermitRanksAheadOfNewRequest() throws {
        let home = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let permit = item(
            source: .buildingPermits2026,
            identifier: "permit",
            status: .active,
            coordinate: try #require(PulseItem.Coordinate(latitude: 38.9002, longitude: -77.0300)),
            openedAt: Date(timeIntervalSince1970: 100)
        )
        let request = item(
            source: .serviceRequests311,
            identifier: "request",
            status: .new,
            coordinate: home,
            openedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(NoteworthyItemRanker.rank([request, permit], homeCoordinate: home).first?.id == permit.id)
    }

    @Test func distantPermitDoesNotReceiveHomePriority() throws {
        let home = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let permit = item(
            source: .ddotConstructionPermits2026,
            identifier: "permit",
            status: .active,
            coordinate: try #require(PulseItem.Coordinate(latitude: 38.9200, longitude: -77.0300)),
            openedAt: Date(timeIntervalSince1970: 100)
        )
        let request = item(
            source: .serviceRequests311,
            identifier: "request",
            status: .new,
            coordinate: home,
            openedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(NoteworthyItemRanker.rank([permit, request], homeCoordinate: home).first?.id == request.id)
    }

    private func item(
        source: PulseItem.Source,
        identifier: String,
        status: PulseItem.Status,
        coordinate: PulseItem.Coordinate,
        openedAt: Date
    ) -> PulseItem {
        PulseItem(
            id: .init(source: source, sourceIdentifier: identifier),
            category: "Test",
            subtype: nil,
            title: "Test item",
            summary: nil,
            status: status,
            openedAt: openedAt,
            updatedAt: nil,
            closedAt: nil,
            coordinate: coordinate,
            address: nil,
            wardOrNeighborhood: nil,
            responsibleAgency: nil,
            sourceAttributes: [],
            sourceURL: nil
        )
    }
}

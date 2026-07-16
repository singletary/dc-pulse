import Foundation
import Testing
@testable import DCPulse

@MainActor
struct WatchedPulseItemTests {
    @Test func retainsSnapshotAndDetectsStatusChange() throws {
        let openedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let active = makeItem(status: .active, openedAt: openedAt)
        let watched = WatchedPulseItem(item: active, now: openedAt)

        #expect(watched.item == active)
        #expect(!watched.hasUnseenStatusChange)

        let resolved = makeItem(status: .resolved, openedAt: openedAt)
        watched.update(from: resolved, now: openedAt.addingTimeInterval(60))

        #expect(watched.item?.status == .resolved)
        #expect(watched.previousStatusRawValue == PulseItem.Status.active.rawValue)
        #expect(watched.hasUnseenStatusChange)

        watched.markStatusChangeSeen()
        #expect(!watched.hasUnseenStatusChange)
    }

    @Test func stableKeyIncludesSource() {
        let request = PulseItem.ID(source: .serviceRequests311, sourceIdentifier: "42")
        let permit = PulseItem.ID(source: .buildingPermits2026, sourceIdentifier: "42")
        #expect(WatchedPulseItem.stableKey(for: request) != WatchedPulseItem.stableKey(for: permit))
    }

    @Test func agingFromNewToActiveDoesNotCreateUnseenChange() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let watched = WatchedPulseItem(item: makeItem(status: .new, openedAt: now), now: now)

        watched.update(from: makeItem(status: .active, openedAt: now), now: now.addingTimeInterval(60))

        #expect(watched.item?.status == .active)
        #expect(watched.previousStatusRawValue == nil)
        #expect(!watched.hasUnseenStatusChange)
    }

    private func makeItem(status: PulseItem.Status, openedAt: Date) -> PulseItem {
        PulseItem(
            id: .init(source: .serviceRequests311, sourceIdentifier: "311-42"),
            category: "Graffiti Removal",
            subtype: nil,
            title: "Graffiti Removal request",
            summary: "Test details",
            status: status,
            openedAt: openedAt,
            updatedAt: openedAt,
            closedAt: status == .resolved ? openedAt : nil,
            coordinate: PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300),
            address: "9999 Example Avenue NW",
            wardOrNeighborhood: "Ward 1",
            responsibleAgency: "DPW",
            sourceAttributes: [],
            sourceURL: nil
        )
    }
}

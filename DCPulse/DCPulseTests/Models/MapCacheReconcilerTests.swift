import Foundation
import Testing
@testable import DCPulse

@MainActor
struct MapCacheReconcilerTests {
    private let reconciler = MapCacheReconciler()

    @Test func completeSourceRefreshReplacesOnlyThatSourcesCachedSlice() {
        let cached311 = item(source: .serviceRequests311, id: "311-old", day: 1)
        let cachedPermit = item(source: .buildingPermits2026, id: "permit-cached", day: 2)
        let fresh311 = item(source: .serviceRequests311, id: "311-fresh", day: 3)

        let result = reconciler.reconcile(
            cachedItems: [cached311, cachedPermit],
            refreshes: [
                .init(
                    source: .serviceRequests311,
                    coverage: .completeAuthoritative,
                    items: [fresh311]
                )
            ]
        )

        #expect(Set(result.items.map(\.id)) == [fresh311.id, cachedPermit.id])
        #expect(result.refreshedSources == [.serviceRequests311])
        #expect(result.retainedCachedSources.isEmpty)
    }

    @Test func partialRefreshUpdatesMatchesAndPreservesUnseenCachedRecords() {
        let cached = item(source: .serviceRequests311, id: "311-existing", day: 1, status: .active)
        let unseen = item(source: .serviceRequests311, id: "311-unseen", day: 2)
        let updated = item(source: .serviceRequests311, id: "311-existing", day: 1, status: .resolved)

        let result = reconciler.reconcile(
            cachedItems: [cached, unseen],
            refreshes: [
                .init(source: .serviceRequests311, coverage: .partial, items: [updated])
            ]
        )

        #expect(result.items.first { $0.id == cached.id }?.status == .resolved)
        #expect(result.items.contains { $0.id == unseen.id })
        #expect(result.refreshedSources == [.serviceRequests311])
        #expect(result.retainedCachedSources == [.serviceRequests311])
    }

    @Test func failedSourceKeepsItsCacheWhileHealthySourceReconciles() {
        let cached311 = item(source: .serviceRequests311, id: "311-cached", day: 1)
        let cachedPermit = item(source: .buildingPermits2026, id: "permit-old", day: 2)
        let freshPermit = item(source: .buildingPermits2026, id: "permit-fresh", day: 3)

        let result = reconciler.reconcile(
            cachedItems: [cached311, cachedPermit],
            refreshes: [
                .init(source: .serviceRequests311, coverage: .failed),
                .init(
                    source: .buildingPermits2026,
                    coverage: .completeAuthoritative,
                    items: [freshPermit]
                )
            ]
        )

        #expect(Set(result.items.map(\.id)) == [cached311.id, freshPermit.id])
        #expect(result.refreshedSources == [.buildingPermits2026])
        #expect(result.retainedCachedSources == [.serviceRequests311])
    }

    @Test func mismatchedSourceItemsCannotLeakIntoAnotherSourcesRefresh() {
        let cached311 = item(source: .serviceRequests311, id: "311-cached", day: 1)
        let mismatchedPermit = item(source: .buildingPermits2026, id: "permit", day: 2)

        let result = reconciler.reconcile(
            cachedItems: [cached311],
            refreshes: [
                .init(
                    source: .serviceRequests311,
                    coverage: .completeAuthoritative,
                    items: [mismatchedPermit]
                )
            ]
        )

        #expect(result.items.isEmpty)
    }

    private func item(
        source: PulseItem.Source,
        id: String,
        day: TimeInterval,
        status: PulseItem.Status = .active
    ) -> PulseItem {
        PulseItem(
            id: .init(source: source, sourceIdentifier: id),
            category: "Test",
            subtype: nil,
            title: id,
            summary: nil,
            status: status,
            openedAt: Date(timeIntervalSince1970: day * 86_400),
            updatedAt: nil,
            closedAt: nil,
            coordinate: SampleData.center,
            address: nil,
            wardOrNeighborhood: nil,
            responsibleAgency: nil,
            sourceAttributes: [],
            sourceURL: nil
        )
    }
}

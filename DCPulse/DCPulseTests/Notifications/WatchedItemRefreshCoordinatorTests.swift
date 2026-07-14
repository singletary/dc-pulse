import Foundation
import Testing
@testable import DCPulse

@MainActor
struct WatchedItemRefreshCoordinatorTests {
    @Test func detectsTransitionsAcrossSourcesAndReportsMissingItems() async throws {
        let request = try #require(SampleData.items.first { $0.id.source == .serviceRequests311 })
        let permit = try #require(SampleData.items.first { $0.id.source == .buildingPermits2026 })
        let resolvedRequest = copy(request, status: .resolved)
        let coordinator = WatchedItemRefreshCoordinator(repositories: [
            StubWatchedRefreshRepository(source: .serviceRequests311, items: [resolvedRequest]),
            StubWatchedRefreshRepository(source: .buildingPermits2026, items: [])
        ])

        let result = try await coordinator.refresh([request, permit])

        #expect(result.transitions == [.init(previousStatus: request.status, item: resolvedRequest)])
        #expect(result.missingIDs == [permit.id])
        #expect(result.failedSources.isEmpty)
    }

    @Test func isolatesSourceFailuresAndDoesNotMarkTheirItemsMissing() async throws {
        let request = try #require(SampleData.items.first { $0.id.source == .serviceRequests311 })
        let permit = try #require(SampleData.items.first { $0.id.source == .buildingPermits2026 })
        let coordinator = WatchedItemRefreshCoordinator(repositories: [
            StubWatchedRefreshRepository(source: .serviceRequests311, items: [], shouldFail: true),
            StubWatchedRefreshRepository(source: .buildingPermits2026, items: [permit])
        ])

        let result = try await coordinator.refresh([request, permit])

        #expect(result.refreshedItems == [permit])
        #expect(result.missingIDs.isEmpty)
        #expect(result.failedSources == [.serviceRequests311])
    }

    private func copy(_ item: PulseItem, status: PulseItem.Status) -> PulseItem {
        PulseItem(
            id: item.id, category: item.category, subtype: item.subtype, title: item.title,
            summary: item.summary, status: status, openedAt: item.openedAt, updatedAt: item.updatedAt,
            closedAt: item.closedAt, coordinate: item.coordinate, address: item.address,
            wardOrNeighborhood: item.wardOrNeighborhood, responsibleAgency: item.responsibleAgency,
            sourceAttributes: item.sourceAttributes, sourceURL: item.sourceURL
        )
    }
}

private struct StubWatchedRefreshRepository: WatchedItemRefreshRepositoryProtocol {
    let source: PulseItem.Source
    let items: [PulseItem]
    var shouldFail = false

    func items(withIdentifiers identifiers: [String]) async throws -> [PulseItem] {
        if shouldFail { throw TestRefreshError.expected }
        return items
    }
}

private enum TestRefreshError: Error { case expected }

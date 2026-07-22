import Foundation
import Testing
@testable import DCPulse

@MainActor
struct PulseDataStoreTests {
    @Test func loadsCurrentLocationContext() async throws {
        let expected = try #require(SampleData.items.first)
        let repository = StubPulseRepository(results: [.success(.init(items: [expected], nextOffset: 1, hasMore: false))])
        let store = PulseDataStore(repository: repository)
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.92, longitude: -77.04))

        await store.load(coordinate: coordinate, placeName: "Current Location")

        #expect(store.state == .loaded)
        #expect(store.searchCoordinate == coordinate)
        #expect(store.placeName == "Current Location")
        #expect(store.items == [expected])
    }

    @Test func usesCompleteStatusSummaryInsteadOfLoadedPageCounts() async throws {
        let loadedItem = try #require(SampleData.items.first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [loadedItem], nextOffset: 1, hasMore: true))
        ])
        let summary = StubStatusSummaryRepository(counts: .init(new: 12, active: 189, resolved: 87))
        let store = PulseDataStore(repository: repository, requestStatusSummaryRepository: summary)

        await store.load()

        #expect(store.requestCount(for: .new) == 12)
        #expect(store.requestCount(for: .active) == 189)
        #expect(store.requestCount(for: .resolved) == 87)
    }

    @Test func exposesCompleteTrendAndCategorySnapshot() async throws {
        let loadedItem = try #require(SampleData.items.first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [loadedItem], nextOffset: 1, hasMore: false))
        ])
        let trend = RequestTrendAnalyzer.Trend(
            category: "Graffiti Removal",
            currentCount: 4,
            previousCount: 1,
            percentChange: 300,
            direction: .increased
        )
        let summary = StubTrendSummaryRepository(
            snapshot: .init(
                trends: [trend],
                categories: ["Graffiti Removal", "Illegal Dumping"],
                categoryCounts: ["Graffiti Removal": 5, "Illegal Dumping": 8]
            )
        )
        let store = PulseDataStore(repository: repository, requestTrendSummaryRepository: summary)

        await store.load()

        #expect(store.requestTrends == [trend])
        #expect(store.requestCategories == ["Graffiti Removal", "Illegal Dumping"])
        #expect(store.requestCategoryCounts == ["Graffiti Removal": 5, "Illegal Dumping": 8])
        #expect(!store.isRequestInsightsLoading)
    }

    @Test func doesNotPresentPartialPageCountsAsCompleteWhenSummariesFail() async throws {
        let loadedItem = try #require(SampleData.items.first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [loadedItem], nextOffset: 1, hasMore: true))
        ])
        let store = PulseDataStore(
            repository: repository,
            requestStatusSummaryRepository: FailingStatusSummaryRepository(),
            requestTrendSummaryRepository: FailingTrendSummaryRepository()
        )

        await store.load()

        #expect(store.state == .loaded)
        #expect(store.requestStatusCountsUnavailable)
        #expect(store.requestInsightsUnavailable)
        #expect(store.requestCategoryCounts.isEmpty)
        #expect(!store.isRequestSummaryLoading)
        #expect(!store.isRequestInsightsLoading)
        #expect(store.sourceWarnings.isEmpty)
    }

    @Test func retriesATransientStatusSummaryFailureOnce() async throws {
        let loadedItem = try #require(SampleData.items.first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [loadedItem], nextOffset: 1, hasMore: false))
        ])
        let summary = TransientStatusSummaryRepository(
            counts: .init(new: 7, active: 11, resolved: 3)
        )
        let store = PulseDataStore(
            repository: repository,
            requestStatusSummaryRepository: summary
        )

        await store.load()

        #expect(store.requestCount(for: .new) == 7)
        #expect(!store.requestStatusCountsUnavailable)
        #expect(await summary.attempts == 2)
    }

    @Test func preservesContextInEmptyAndErrorStates() async throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.90, longitude: -77.02))
        let emptyStore = PulseDataStore(repository: StubPulseRepository(results: [.success(.init(items: [], nextOffset: 0, hasMore: false))]))
        await emptyStore.load(coordinate: coordinate, placeName: "Current Location")
        #expect(emptyStore.state == .empty)
        #expect(emptyStore.searchCoordinate == coordinate)

        let failedStore = PulseDataStore(repository: StubPulseRepository(results: [.failure(TestError.expected)]))
        await failedStore.load(coordinate: coordinate, placeName: "Current Location")
        if case .failed = failedStore.state { } else { Issue.record("Expected failed state") }
        #expect(failedStore.placeName == "Current Location")
    }

    @Test func usesHalfMileByDefaultAndReloadsSelectedRadius() async {
        let emptyPage = PulsePage(items: [], nextOffset: 0, hasMore: false)
        let repository = StubPulseRepository(results: [.success(emptyPage), .success(emptyPage)])
        let store = PulseDataStore(repository: repository)

        await store.load()
        #expect(store.radius == .halfMile)
        #expect(repository.radiusRequests == [0.5])

        await store.selectRadius(.quarterMile)
        #expect(store.radius == .quarterMile)
        #expect(repository.radiusRequests == [0.5, 0.25])
    }

    @Test func radiusCopyMatchesControlAndAccessibilityContexts() {
        #expect(PulseDataStore.Radius.quarterMile.compactLabel == "0.25 mi")
        #expect(PulseDataStore.Radius.halfMile.distanceLabel == "0.5 miles")
        #expect(PulseDataStore.Radius.halfMile.radiusLabel == "0.5-mile radius")
        #expect(PulseDataStore.Radius.halfMile.accessibilityLabel == "half-mile radius")
        #expect(PulseDataStore.Radius.oneMile.distanceLabel == "1 mile")
    }

    @Test func reloadsSelectedTimeRange() async {
        let emptyPage = PulsePage(items: [], nextOffset: 0, hasMore: false)
        let repository = StubPulseRepository(results: [.success(emptyPage), .success(emptyPage)])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.selectPeriod(.ninetyDays)

        #expect(store.period == .ninetyDays)
        #expect(repository.daysRequests == [30, 90])
    }

    @Test func appendsNextPageWhenRequested() async throws {
        let first = try #require(SampleData.items.first)
        let second = try #require(SampleData.items.dropFirst().first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [first], nextOffset: 1, hasMore: true)),
            .success(.init(items: [second], nextOffset: 2, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        #expect(store.items == [first])
        #expect(store.hasMore)

        await store.loadMore()
        #expect(store.items == [first, second])
        #expect(!store.hasMore)
        #expect(repository.offsetRequests == [0, 1])
        #expect(repository.limitRequests == [30, 30])
    }

    @Test func keepsLoadMorePartialFailuresOutOfPrimarySourceWarnings() async throws {
        let first = try #require(SampleData.items.first)
        let second = try #require(SampleData.items.dropFirst().first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [first], nextOffset: 1, hasMore: true)),
            .success(.init(
                items: [second],
                nextOffset: 2,
                hasMore: true,
                warnings: ["DC 311 records are temporarily unavailable."]
            ))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.loadMore()

        #expect(Set(store.items.map(\.id)) == Set([first.id, second.id]))
        #expect(store.sourceWarnings.isEmpty)
        #expect(store.loadMoreError == "Some additional results could not be refreshed. Try again.")
    }

    @Test func clearsAStalePrimaryWarningWhenThatSourceRecovers() async throws {
        let request = try #require(SampleData.items.first { $0.id.source == .serviceRequests311 })
        let permit = try #require(SampleData.items.first { $0.id.source == .buildingPermits2026 })
        let repository = StubPulseRepository(results: [
            .success(.init(
                items: [permit],
                nextOffset: 1,
                hasMore: true,
                warnings: ["DC 311 records are temporarily unavailable."]
            )),
            .success(.init(items: [request], nextOffset: 2, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        #expect(store.sourceWarnings == ["DC 311 records are temporarily unavailable."])

        await store.loadMore()
        #expect(store.sourceWarnings.isEmpty)
    }

    @Test func prefetchesSummaryPagesUntilTheSourceIsComplete() async throws {
        let first = try #require(SampleData.items.first)
        let second = try #require(SampleData.items.dropFirst().first)
        let third = try #require(SampleData.items.dropFirst(2).first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [first], nextOffset: 1, hasMore: true)),
            .success(.init(items: [second], nextOffset: 2, hasMore: true)),
            .success(.init(items: [third], nextOffset: 3, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.prefetchSummary()

        #expect(store.items == [first, second, third])
        #expect(repository.offsetRequests == [0, 1, 2])
        #expect(!store.hasMore)
    }

    @Test func largerMapRadiusAlsoIncludesCloseInCoverage() async throws {
        let broadItem = try #require(SampleData.items.first)
        let closeItem = try #require(SampleData.items.dropFirst().first)
        let laterBroadItem = try #require(SampleData.items.dropFirst(2).first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [broadItem], nextOffset: 1, hasMore: false)),
            .success(.init(items: [closeItem], nextOffset: 1, hasMore: false)),
            .success(.init(items: [broadItem, laterBroadItem], nextOffset: 2, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.prepareMapResults()

        #expect(Set(store.items.map(\.id)) == Set([broadItem.id, closeItem.id, laterBroadItem.id]))
        #expect(repository.radiusRequests == [0.5, 0.25, 0.5])
        #expect(repository.limitRequests == [30, 150, 150])
        #expect(!store.isMapCoverageLoading)
    }

    @Test func selectedRadiusCoverageStillLoadsWhenCloseInVerificationFails() async throws {
        let broadItem = try #require(SampleData.items.first)
        let laterBroadItem = try #require(SampleData.items.dropFirst().first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [broadItem], nextOffset: 1, hasMore: false)),
            .failure(TestError.expected),
            .success(.init(items: [laterBroadItem], nextOffset: 1, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.prepareMapResults()

        #expect(Set(store.items.map(\.id)) == Set([broadItem.id, laterBroadItem.id]))
        #expect(repository.radiusRequests == [0.5, 0.25, 0.5])
        #expect(store.sourceWarnings.isEmpty)
        #expect(store.mapCoverageWarning?.contains("close-in") == true)
        #expect(!store.isMapCoverageLoading)
    }

    @Test func keepsMapPaginationWarningsScopedToTheMap() async throws {
        let initial = try #require(SampleData.items.first)
        let closeIn = try #require(SampleData.items.dropFirst().first)
        let selectedRadius = try #require(SampleData.items.dropFirst(2).first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [initial], nextOffset: 1, hasMore: false)),
            .success(.init(
                items: [closeIn],
                nextOffset: 1,
                hasMore: false,
                warnings: ["DC 311 records are temporarily unavailable."]
            )),
            .success(.init(items: [selectedRadius], nextOffset: 1, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.prepareMapResults()

        #expect(store.sourceWarnings.isEmpty)
        #expect(store.mapCoverageWarning == "Some map results could not be refreshed. Try again.")
    }

    @Test func resetsSearchOptionsWithOneReload() async {
        let emptyPage = PulsePage(items: [], nextOffset: 0, hasMore: false)
        let repository = StubPulseRepository(results: [
            .success(emptyPage), .success(emptyPage), .success(emptyPage), .success(emptyPage)
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.selectRadius(.oneMile)
        await store.selectPeriod(.ninetyDays)
        await store.resetSearchOptions()

        #expect(store.radius == .halfMile)
        #expect(store.period == .thirtyDays)
        #expect(repository.radiusRequests.last == 0.5)
        #expect(repository.daysRequests.last == 30)
    }

    @Test func reusesFreshCachedResultsWithoutCallingTheRepository() async throws {
        let item = try #require(SampleData.items.first)
        let suite = "PulseDataStoreTests.cache.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let firstRepository = StubPulseRepository(results: [
            .success(.init(items: [item], nextOffset: 1, hasMore: false))
        ])
        let firstStore = PulseDataStore(repository: firstRepository, defaults: defaults)
        await firstStore.load()

        let secondRepository = StubPulseRepository(results: [])
        let secondStore = PulseDataStore(repository: secondRepository, defaults: defaults)
        await secondStore.load()

        #expect(secondStore.items == [item])
        #expect(secondRepository.offsetRequests.isEmpty)
    }
}

private final class StubPulseRepository: PulseRepositoryProtocol, @unchecked Sendable {
    private var results: [Result<PulsePage, Error>]
    private(set) var radiusRequests: [Double] = []
    private(set) var offsetRequests: [Int] = []
    private(set) var limitRequests: [Int] = []
    private(set) var daysRequests: [Int] = []

    init(results: [Result<PulsePage, Error>]) { self.results = results }

    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) async throws -> PulsePage {
        radiusRequests.append(radiusMiles)
        daysRequests.append(days)
        offsetRequests.append(offset)
        limitRequests.append(limit)
        return try results.removeFirst().get()
    }
}

private enum TestError: Error { case expected }

private struct StubStatusSummaryRepository: RequestStatusSummaryRepositoryProtocol {
    let counts: RequestStatusCounts

    func statusCounts(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int) async throws -> RequestStatusCounts {
        counts
    }
}

private struct StubTrendSummaryRepository: RequestTrendSummaryRepositoryProtocol {
    let snapshot: RequestTrendSnapshot

    func trendSnapshot(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int) async throws -> RequestTrendSnapshot {
        snapshot
    }
}

private struct FailingStatusSummaryRepository: RequestStatusSummaryRepositoryProtocol {
    func statusCounts(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int) async throws -> RequestStatusCounts {
        throw TestError.expected
    }
}

private struct FailingTrendSummaryRepository: RequestTrendSummaryRepositoryProtocol {
    func trendSnapshot(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int) async throws -> RequestTrendSnapshot {
        throw TestError.expected
    }
}

private actor TransientStatusSummaryRepository: RequestStatusSummaryRepositoryProtocol {
    private(set) var attempts = 0
    let counts: RequestStatusCounts

    init(counts: RequestStatusCounts) { self.counts = counts }

    func statusCounts(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int) async throws -> RequestStatusCounts {
        attempts += 1
        if attempts == 1 { throw TestError.expected }
        return counts
    }
}

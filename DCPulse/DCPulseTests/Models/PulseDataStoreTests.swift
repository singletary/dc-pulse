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
        let repository = StubPulseRepository(results: [
            .success(.init(items: [broadItem], nextOffset: 1, hasMore: false)),
            .success(.init(items: [closeItem], nextOffset: 1, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.prepareMapResults()

        #expect(Set(store.items.map(\.id)) == Set([broadItem.id, closeItem.id]))
        #expect(repository.radiusRequests == [0.5, 0.25])
        #expect(repository.limitRequests == [30, 150])
        #expect(!store.isMapCoverageLoading)
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

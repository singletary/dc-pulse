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

    @Test func refreshesTrendContextAcrossRadiusPeriodAndFollowedPlaceChanges() async throws {
        let emptyPage = PulsePage(items: [], nextOffset: 0, hasMore: false)
        let repository = StubPulseRepository(results: Array(repeating: .success(emptyPage), count: 4))
        let trends = RecordingTrendSummaryRepository()
        let store = PulseDataStore(repository: repository, requestTrendSummaryRepository: trends)
        let followedCoordinate = try #require(PulseItem.Coordinate(latitude: 38.93, longitude: -77.07))

        await store.load()
        await store.selectRadius(.oneMile)
        await store.selectPeriod(.ninetyDays)
        await store.load(coordinate: followedCoordinate, placeName: "Tenleytown")

        let requests = await trends.requests
        #expect(requests == [
            .init(coordinate: SampleData.center, radiusMiles: 0.5, days: 30),
            .init(coordinate: SampleData.center, radiusMiles: 1, days: 30),
            .init(coordinate: SampleData.center, radiusMiles: 1, days: 90),
            .init(coordinate: followedCoordinate, radiusMiles: 1, days: 90)
        ])
        #expect(store.placeName == "Tenleytown")
        #expect(store.requestTrendSnapshot?.provenance?.coordinate == followedCoordinate)
        #expect(store.requestTrendSnapshot?.provenance?.radiusMiles == 1)
        #expect(store.requestTrendSnapshot?.provenance?.selectedDays == 90)
    }

    @Test func statusSelectionUsesCompleteScopedCategoryCountsAndResetsToAll() async throws {
        let repository = StubPulseRepository(results: [
            .success(.init(items: [], nextOffset: 0, hasMore: false))
        ])
        let categories = DelayedCategorySummaryRepository()
        let store = PulseDataStore(
            repository: repository,
            requestCategorySummaryRepository: categories
        )

        await store.load()
        #expect(store.selectedRequestStatus == nil)
        #expect(store.requestCategoryCounts == ["All requests": 20])

        await store.selectRequestStatus(.active)
        #expect(store.selectedRequestStatus == .active)
        #expect(store.requestCategoryCounts == ["Active requests": 8])

        await store.selectRequestStatus(nil)
        #expect(store.selectedRequestStatus == nil)
        #expect(store.requestCategoryCounts == ["All requests": 20])
        #expect(await categories.requestedStatuses == [nil, .active])
    }

    @Test func slowerStatusSelectionCannotReplaceTheLatestCategoryCounts() async throws {
        let repository = StubPulseRepository(results: [
            .success(.init(items: [], nextOffset: 0, hasMore: false))
        ])
        let categories = DelayedCategorySummaryRepository()
        let store = PulseDataStore(
            repository: repository,
            requestCategorySummaryRepository: categories
        )
        await store.load()

        let earlierSelection = Task { await store.selectRequestStatus(.new) }
        try await Task.sleep(for: .milliseconds(20))
        await store.selectRequestStatus(.resolved)
        await earlierSelection.value

        #expect(store.selectedRequestStatus == .resolved)
        #expect(store.requestCategoryCounts == ["Resolved requests": 11])
        #expect(!store.isRequestCategorySummaryLoading)
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
            .success(.init(items: [broadItem], nextOffset: 1, hasMore: true)),
            .success(.init(items: [closeItem], nextOffset: 1, hasMore: false)),
            .success(.init(items: [broadItem, laterBroadItem], nextOffset: 2, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.prepareMapResults()

        #expect(Set(store.items.map(\.id)) == Set([broadItem.id, closeItem.id, laterBroadItem.id]))
        #expect(repository.radiusRequests == [0.5, 0.25, 0.5])
        #expect(repository.offsetRequests == [0, 0, 1])
        #expect(repository.limitRequests == [30, 150, 150])
        #expect(!store.isMapCoverageLoading)
    }

    @Test func sameCenterWiderRadiiRetainEveryQuarterMileIdentifier() async throws {
        let quarterA = cacheItem(source: .serviceRequests311, id: "quarter-a", day: 4)
        let quarterB = cacheItem(source: .buildingPermits2026, id: "quarter-b", day: 3)
        let half = cacheItem(source: .ddotConstructionPermits2026, id: "half", day: 2)
        let one = cacheItem(source: .serviceRequests311, id: "one", day: 1)
        let repository = RadiusInvariantRepository(
            quarterMile: [quarterA, quarterB],
            halfMile: [quarterA, half],
            oneMile: [half, one]
        )
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.selectRadius(.quarterMile)
        await store.prepareMapResults()
        let quarterMileIDs = Set(store.items.map(\.id))

        await store.selectRadius(.halfMile)
        await store.prepareMapResults()
        let halfMileIDs = Set(store.items.map(\.id))

        await store.selectRadius(.oneMile)
        await store.prepareMapResults()
        let oneMileIDs = Set(store.items.map(\.id))

        #expect(quarterMileIDs == [quarterA.id, quarterB.id])
        #expect(quarterMileIDs.isSubset(of: halfMileIDs))
        #expect(quarterMileIDs.isSubset(of: oneMileIDs))
        #expect(oneMileIDs == [quarterA.id, quarterB.id, half.id, one.id])
    }

    @Test func mapReusesACompleteCompatibleNearYouPageWithoutAnotherSelectedRadiusRequest() async throws {
        let item = try #require(SampleData.items.first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [item], nextOffset: 1, hasMore: false)),
            .success(.init(items: [item], nextOffset: 1, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.selectRadius(.quarterMile)
        await store.prepareMapResults()

        #expect(repository.radiusRequests == [0.5, 0.25])
        #expect(repository.offsetRequests == [0, 0])
        #expect(store.items == [item])
    }

    @Test func selectedRadiusCoverageStillLoadsWhenCloseInVerificationFails() async throws {
        let broadItem = try #require(SampleData.items.first)
        let laterBroadItem = try #require(SampleData.items.dropFirst().first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [broadItem], nextOffset: 1, hasMore: true)),
            .failure(TestError.expected),
            .success(.init(items: [laterBroadItem], nextOffset: 1, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.prepareMapResults()

        #expect(Set(store.items.map(\.id)) == Set([broadItem.id, laterBroadItem.id]))
        #expect(repository.radiusRequests == [0.5, 0.25, 0.5])
        #expect(store.sourceWarnings.isEmpty)
        #expect(store.mapCoverageWarning == "Some map results could not update. Existing markers are still available.")
        #expect(store.mapCoverageIssues == [
            .init(
                pass: .closeIn,
                message: "These results could not update. Markers already on the map remain available."
            )
        ])
        #expect(!store.isMapCoverageLoading)
    }

    @Test func keepsMapPaginationWarningsScopedToTheMap() async throws {
        let initial = try #require(SampleData.items.first)
        let closeIn = try #require(SampleData.items.dropFirst().first)
        let selectedRadius = try #require(SampleData.items.dropFirst(2).first)
        let repository = RadiusScopedWarningRepository(
            initial: initial,
            closeIn: closeIn,
            selectedRadius: selectedRadius
        )
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.prepareMapResults()

        #expect(store.sourceWarnings.isEmpty)
        #expect(store.mapCoverageWarning == "Some map results could not update. Existing markers are still available.")
        #expect(store.mapCoverageIssues == [
            .init(
                pass: .closeIn,
                message: "DC 311 records are temporarily unavailable. Markers already on the map remain available."
            )
        ])
    }

    @Test func labelsSelectedRadiusPartialFailuresAndRetryClearsThem() async throws {
        let initial = try #require(SampleData.items.first)
        let selectedRadius = try #require(SampleData.items.dropFirst(2).first)
        let repository = StubPulseRepository(results: [
            .success(.init(items: [initial], nextOffset: 1, hasMore: false)),
            .success(.init(items: [initial], nextOffset: 1, hasMore: true)),
            .success(.init(
                items: [selectedRadius],
                nextOffset: 1,
                hasMore: false,
                warnings: ["Building Permits records are temporarily unavailable."]
            )),
            .success(.init(items: [selectedRadius], nextOffset: 1, hasMore: false))
        ])
        let store = PulseDataStore(repository: repository)

        await store.load()
        await store.selectRadius(.quarterMile)
        await store.prepareMapResults()

        #expect(store.mapCoverageIssues == [
            .init(
                pass: .selectedRadius,
                message: "Building Permits records are temporarily unavailable. Markers already on the map remain available."
            )
        ])
        #expect(store.mapCoverageIssues[0].pass.label(selectedRadius: store.radius) == "Selected 0.25-mile coverage")

        await store.retryMapCoverage()

        #expect(store.mapCoverageIssues.isEmpty)
        #expect(store.mapCoverageWarning == nil)
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
        let mapCacheStore = TransientMapCacheStore()
        let firstRepository = StubPulseRepository(results: [
            .success(.init(items: [item], nextOffset: 1, hasMore: false))
        ])
        let firstStore = PulseDataStore(
            repository: firstRepository,
            defaults: defaults,
            mapCacheStore: mapCacheStore
        )
        await firstStore.load()

        let secondRepository = StubPulseRepository(results: [])
        let secondStore = PulseDataStore(
            repository: secondRepository,
            defaults: defaults,
            mapCacheStore: mapCacheStore
        )
        await secondStore.load()

        #expect(secondStore.items == [item])
        #expect(secondRepository.offsetRequests.isEmpty)
        #expect(secondStore.lastUpdated != nil)
        #expect(secondStore.isShowingCachedResults)
        #expect(!secondStore.cachedResultsAreStale)
    }

    @Test func showsStaleCachedResultsWhenLiveRefreshFails() async throws {
        let item = try #require(SampleData.items.first)
        let savedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let mapCacheStore = TransientMapCacheStore()
        let writer = PulseDataStore(
            repository: StubPulseRepository(results: [
                .success(.init(items: [item], nextOffset: 1, hasMore: false))
            ]),
            mapCacheStore: mapCacheStore,
            now: { savedAt }
        )
        await writer.load()

        let reader = PulseDataStore(
            repository: StubPulseRepository(results: [.failure(TestError.expected)]),
            mapCacheStore: mapCacheStore,
            now: { savedAt.addingTimeInterval(60 * 60) }
        )
        await reader.load()

        #expect(reader.items == [item])
        #expect(reader.state == .loaded)
        #expect(reader.lastUpdated == savedAt)
        #expect(reader.isShowingCachedResults)
        #expect(reader.cachedResultsAreStale)
        #expect(reader.sourceWarnings.contains("Live refresh failed. Cached results remain available."))
    }

    @Test func rejectsCachedResultsOutsideTheTwentyFourHourWindow() async throws {
        let cached = try #require(SampleData.items.first)
        let live = try #require(SampleData.items.dropFirst().first)
        let savedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let mapCacheStore = TransientMapCacheStore()
        let writer = PulseDataStore(
            repository: StubPulseRepository(results: [
                .success(.init(items: [cached], nextOffset: 1, hasMore: false))
            ]),
            mapCacheStore: mapCacheStore,
            now: { savedAt }
        )
        await writer.load()

        let reader = PulseDataStore(
            repository: StubPulseRepository(results: [
                .success(.init(items: [live], nextOffset: 1, hasMore: false))
            ]),
            mapCacheStore: mapCacheStore,
            now: { savedAt.addingTimeInterval(25 * 60 * 60) }
        )
        await reader.load()

        #expect(reader.items == [live])
        #expect(!reader.isShowingCachedResults)
        #expect(!reader.cachedResultsAreStale)
    }

    @Test func reconcilesACompletedHealthySourceWithoutDiscardingAnotherCachedSource() async throws {
        let cached311 = cacheItem(source: .serviceRequests311, id: "311-cached", day: 1)
        let cachedPermit = cacheItem(source: .buildingPermits2026, id: "permit-cached", day: 2)
        let fresh311 = cacheItem(source: .serviceRequests311, id: "311-fresh", day: 3)
        let savedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let mapCacheStore = TransientMapCacheStore()
        let writer = PulseDataStore(
            repository: StubPulseRepository(results: [
                .success(.init(items: [], nextOffset: 0, hasMore: false)),
                .success(.init(items: [cached311, cachedPermit], nextOffset: 2, hasMore: false))
            ]),
            mapCacheStore: mapCacheStore,
            now: { savedAt }
        )
        await writer.load()
        await writer.selectRadius(.quarterMile)

        let reader = PulseDataStore(
            repository: StubPulseRepository(results: [
                .success(.init(items: [fresh311], nextOffset: 1, hasMore: false)),
                .success(.init(items: [fresh311], nextOffset: 1, hasMore: false))
            ]),
            mapCacheStore: mapCacheStore,
            now: { savedAt.addingTimeInterval(60 * 60) }
        )
        await reader.selectRadius(.quarterMile)
        await reader.prepareMapResults()

        #expect(Set(reader.items.map(\.id)) == [fresh311.id, cachedPermit.id])
        #expect(reader.isShowingCachedResults)
        #expect(reader.cachedResultsAreStale)

        let relaunch = PulseDataStore(
            repository: StubPulseRepository(results: [.failure(TestError.expected)]),
            mapCacheStore: mapCacheStore,
            now: { savedAt.addingTimeInterval(2 * 60 * 60) }
        )
        await relaunch.selectRadius(.quarterMile)

        #expect(Set(relaunch.items.map(\.id)) == [fresh311.id, cachedPermit.id])
        #expect(relaunch.lastUpdated == savedAt)
        #expect(relaunch.cachedResultsAreStale)
    }

    @Test func retainsFreshCachesForMultipleRoundedSearchContexts() async throws {
        let firstItem = try #require(SampleData.items.first)
        let secondItem = try #require(SampleData.items.dropFirst().first)
        let firstCoordinate = try #require(PulseItem.Coordinate(latitude: 38.90, longitude: -77.04))
        let secondCoordinate = try #require(PulseItem.Coordinate(latitude: 38.93, longitude: -77.07))
        let mapCacheStore = TransientMapCacheStore()
        let writingRepository = StubPulseRepository(results: [
            .success(.init(items: [firstItem], nextOffset: 1, hasMore: false)),
            .success(.init(items: [secondItem], nextOffset: 1, hasMore: false))
        ])
        let writingStore = PulseDataStore(
            repository: writingRepository,
            mapCacheStore: mapCacheStore
        )
        await writingStore.load(coordinate: firstCoordinate, placeName: "First")
        await writingStore.load(coordinate: secondCoordinate, placeName: "Second")

        let firstReaderRepository = StubPulseRepository(results: [])
        let firstReader = PulseDataStore(
            repository: firstReaderRepository,
            mapCacheStore: mapCacheStore
        )
        await firstReader.load(coordinate: firstCoordinate, placeName: "First")

        let secondReaderRepository = StubPulseRepository(results: [])
        let secondReader = PulseDataStore(
            repository: secondReaderRepository,
            mapCacheStore: mapCacheStore
        )
        await secondReader.load(coordinate: secondCoordinate, placeName: "Second")

        #expect(firstReader.items == [firstItem])
        #expect(secondReader.items == [secondItem])
        #expect(firstReaderRepository.offsetRequests.isEmpty)
        #expect(secondReaderRepository.offsetRequests.isEmpty)
    }

    @Test func roundedCacheHitPreservesTheRequestedExactCenter() async throws {
        let item = try #require(SampleData.items.first)
        let cachedCoordinate = try #require(PulseItem.Coordinate(
            latitude: 38.90721,
            longitude: -77.03691
        ))
        let requestedCoordinate = try #require(PulseItem.Coordinate(
            latitude: 38.90719,
            longitude: -77.03689
        ))
        let mapCacheStore = TransientMapCacheStore()
        let writer = PulseDataStore(
            repository: StubPulseRepository(results: [
                .success(.init(items: [item], nextOffset: 1, hasMore: false))
            ]),
            mapCacheStore: mapCacheStore
        )
        await writer.load(coordinate: cachedCoordinate, placeName: "Cached")

        let readerRepository = StubPulseRepository(results: [])
        let reader = PulseDataStore(
            repository: readerRepository,
            mapCacheStore: mapCacheStore
        )
        await reader.load(coordinate: requestedCoordinate, placeName: "Requested")

        #expect(reader.searchCoordinate == requestedCoordinate)
        #expect(reader.placeName == "Requested")
        #expect(reader.items == [item])
        #expect(readerRepository.offsetRequests.isEmpty)
    }

    @Test func migratesFreshLegacyUserDefaultsCacheAfterProtectedStoreWrite() async throws {
        let item = try #require(SampleData.items.first)
        let suite = "PulseDataStoreTests.legacyCache.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let savedAt = Date(timeIntervalSince1970: 2_000)
        let fixture = LegacyCacheFixture(
            savedAt: savedAt,
            coordinate: SampleData.center,
            radius: .halfMile,
            period: .thirtyDays,
            placeName: "Downtown DC",
            items: [item],
            nextOffset: 1,
            hasMore: false,
            warnings: [],
            requestStatusCounts: nil,
            requestTrendSnapshot: nil,
            requestCategoryCounts: nil
        )
        defaults.set(try JSONEncoder().encode(fixture), forKey: "dcPulse.requestCache.v4")
        let mapCacheStore = TransientMapCacheStore()
        let repository = StubPulseRepository(results: [])
        let store = PulseDataStore(
            repository: repository,
            defaults: defaults,
            mapCacheStore: mapCacheStore,
            now: { savedAt.addingTimeInterval(60) }
        )

        await store.load(coordinate: SampleData.center)

        #expect(store.items == [item])
        #expect(repository.offsetRequests.isEmpty)
        #expect(defaults.data(forKey: "dcPulse.requestCache.v4") == nil)
        let context = MapCacheContext(
            coordinate: SampleData.center,
            radiusMiles: 0.5,
            periodDays: 30
        )
        #expect(await mapCacheStore.record(for: context) != nil)
    }

    @Test func retainsLegacyCacheWhenProtectedStoreMigrationFails() async throws {
        let item = try #require(SampleData.items.first)
        let suite = "PulseDataStoreTests.failedLegacyMigration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let savedAt = Date(timeIntervalSince1970: 2_000)
        let legacyData = try JSONEncoder().encode(LegacyCacheFixture(
            savedAt: savedAt,
            coordinate: SampleData.center,
            radius: .halfMile,
            period: .thirtyDays,
            placeName: "Downtown DC",
            items: [item],
            nextOffset: 1,
            hasMore: false,
            warnings: [],
            requestStatusCounts: nil,
            requestTrendSnapshot: nil,
            requestCategoryCounts: nil
        ))
        defaults.set(legacyData, forKey: "dcPulse.requestCache.v4")
        let store = PulseDataStore(
            repository: StubPulseRepository(results: []),
            defaults: defaults,
            mapCacheStore: FailingMapCacheStore(),
            now: { savedAt.addingTimeInterval(60) }
        )

        await store.load(coordinate: SampleData.center)

        #expect(store.items == [item])
        #expect(defaults.data(forKey: "dcPulse.requestCache.v4") == legacyData)
    }
}

private func cacheItem(
    source: PulseItem.Source,
    id: String,
    day: TimeInterval
) -> PulseItem {
    PulseItem(
        id: .init(source: source, sourceIdentifier: id),
        category: "Test",
        subtype: nil,
        title: id,
        summary: nil,
        status: .active,
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

private struct LegacyCacheFixture: Encodable {
    let savedAt: Date
    let coordinate: PulseItem.Coordinate
    let radius: PulseDataStore.Radius
    let period: PulseDataStore.Period
    let placeName: String
    let items: [PulseItem]
    let nextOffset: Int
    let hasMore: Bool
    let warnings: [String]
    let requestStatusCounts: RequestStatusCounts?
    let requestTrendSnapshot: RequestTrendSnapshot?
    let requestCategoryCounts: [String: Int]?
}

private actor FailingMapCacheStore: MapCacheStoreProtocol {
    func record(for context: MapCacheContext) -> MapCacheRecord? { nil }
    func mostRecentRecord() -> MapCacheRecord? { nil }
    func save(_ record: MapCacheRecord) throws { throw TestError.expected }
}

private actor RadiusScopedWarningRepository: PulseRepositoryProtocol {
    private let initial: PulseItem
    private let closeIn: PulseItem
    private let selectedRadius: PulseItem
    private var hasLoadedInitialPage = false

    init(initial: PulseItem, closeIn: PulseItem, selectedRadius: PulseItem) {
        self.initial = initial
        self.closeIn = closeIn
        self.selectedRadius = selectedRadius
    }

    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) -> PulsePage {
        guard hasLoadedInitialPage else {
            hasLoadedInitialPage = true
            return .init(items: [initial], nextOffset: 1, hasMore: false)
        }
        if radiusMiles == 0.25 {
            return .init(
                items: [closeIn],
                nextOffset: 1,
                hasMore: false,
                warnings: ["DC 311 records are temporarily unavailable."]
            )
        }
        return .init(items: [selectedRadius], nextOffset: 1, hasMore: false)
    }
}

private actor RadiusInvariantRepository: PulseRepositoryProtocol {
    let quarterMile: [PulseItem]
    let halfMile: [PulseItem]
    let oneMile: [PulseItem]

    init(
        quarterMile: [PulseItem],
        halfMile: [PulseItem],
        oneMile: [PulseItem]
    ) {
        self.quarterMile = quarterMile
        self.halfMile = halfMile
        self.oneMile = oneMile
    }

    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) -> PulsePage {
        let items = switch radiusMiles {
        case 0.25: quarterMile
        case 0.5: halfMile
        default: oneMile
        }
        return .init(items: items, nextOffset: offset + items.count, hasMore: false)
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

private actor RecordingTrendSummaryRepository: RequestTrendSummaryRepositoryProtocol {
    struct Request: Equatable, Sendable {
        let coordinate: PulseItem.Coordinate
        let radiusMiles: Double
        let days: Int
    }

    private(set) var requests: [Request] = []

    func trendSnapshot(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async throws -> RequestTrendSnapshot {
        requests.append(.init(coordinate: coordinate, radiusMiles: radiusMiles, days: days))
        let refreshedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let midpoint = refreshedAt.addingTimeInterval(TimeInterval(-days * 24 * 60 * 60 / 2))
        let start = refreshedAt.addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
        return .init(
            trends: [],
            categories: [],
            categoryCounts: [:],
            provenance: .init(
                source: .serviceRequests311,
                coordinate: coordinate,
                radiusMiles: radiusMiles,
                selectedDays: days,
                currentPeriod: .init(start: midpoint, end: refreshedAt),
                previousPeriod: .init(start: start, end: midpoint),
                refreshedAt: refreshedAt
            )
        )
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

private actor DelayedCategorySummaryRepository: RequestCategorySummaryRepositoryProtocol {
    private(set) var requestedStatuses: [PulseItem.Status?] = []

    func categoryCounts(
        status: PulseItem.Status?,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async throws -> [String: Int] {
        requestedStatuses.append(status)
        switch status {
        case .new:
            try await Task.sleep(for: .milliseconds(150))
            return ["New requests": 3]
        case .active:
            return ["Active requests": 8]
        case .resolved:
            try await Task.sleep(for: .milliseconds(5))
            return ["Resolved requests": 11]
        case .unknown:
            return [:]
        case nil:
            return ["All requests": 20]
        }
    }
}

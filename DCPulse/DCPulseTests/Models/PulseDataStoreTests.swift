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
}

private final class StubPulseRepository: PulseRepositoryProtocol, @unchecked Sendable {
    private var results: [Result<PulsePage, Error>]
    private(set) var radiusRequests: [Double] = []
    private(set) var offsetRequests: [Int] = []
    private(set) var limitRequests: [Int] = []

    init(results: [Result<PulsePage, Error>]) { self.results = results }

    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) async throws -> PulsePage {
        radiusRequests.append(radiusMiles)
        offsetRequests.append(offset)
        limitRequests.append(limit)
        return try results.removeFirst().get()
    }
}

private enum TestError: Error { case expected }

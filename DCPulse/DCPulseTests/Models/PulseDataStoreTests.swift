import Foundation
import Testing
@testable import DCPulse

@MainActor
struct PulseDataStoreTests {
    @Test func loadsCurrentLocationContext() async throws {
        let expected = try #require(SampleData.items.first)
        let repository = StubPulseRepository(result: .success([expected]))
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
        let emptyStore = PulseDataStore(repository: StubPulseRepository(result: .success([])))
        await emptyStore.load(coordinate: coordinate, placeName: "Current Location")
        #expect(emptyStore.state == .empty)
        #expect(emptyStore.searchCoordinate == coordinate)

        let failedStore = PulseDataStore(repository: StubPulseRepository(result: .failure(TestError.expected)))
        await failedStore.load(coordinate: coordinate, placeName: "Current Location")
        if case .failed = failedStore.state { } else { Issue.record("Expected failed state") }
        #expect(failedStore.placeName == "Current Location")
    }
}

private struct StubPulseRepository: PulseRepositoryProtocol {
    let result: Result<[PulseItem], Error>
    func nearbyItems(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int) async throws -> [PulseItem] {
        try result.get()
    }
}

private enum TestError: Error { case expected }

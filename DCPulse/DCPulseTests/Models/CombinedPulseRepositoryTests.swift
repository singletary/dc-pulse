import Foundation
import Testing
@testable import DCPulse

@MainActor
struct CombinedPulseRepositoryTests {
    @Test func combinesSourcesAndSortsNewestFirst() async throws {
        let older = try #require(SampleData.items.first)
        let newer = try #require(SampleData.items.dropFirst().first)
        let repository = CombinedPulseRepository(sources: [
            .init(name: "First", repository: FixedRepository(result: .success(.init(items: [older], nextOffset: 1, hasMore: false)))),
            .init(name: "Second", repository: FixedRepository(result: .success(.init(items: [newer], nextOffset: 1, hasMore: true))))
        ])

        let page = try await repository.nearbyItems(
            coordinate: SampleData.center, radiusMiles: 0.5, days: 30, offset: 0, limit: 30
        )

        #expect(page.items == [newer, older].sorted { $0.openedAt > $1.openedAt })
        #expect(page.nextOffset == 15)
        #expect(page.hasMore)
        #expect(page.warnings.isEmpty)
    }

    @Test func returnsHealthySourceWithWarningWhenAnotherSourceFails() async throws {
        let item = try #require(SampleData.items.first)
        let repository = CombinedPulseRepository(sources: [
            .init(name: "DC 311", repository: FixedRepository(result: .failure(TestFailure.expected))),
            .init(name: "Building Permits", repository: FixedRepository(result: .success(.init(items: [item], nextOffset: 1, hasMore: false))))
        ])

        let page = try await repository.nearbyItems(
            coordinate: SampleData.center, radiusMiles: 0.5, days: 30, offset: 0, limit: 30
        )

        #expect(page.items == [item])
        #expect(page.warnings == ["DC 311 records are temporarily unavailable."])
    }

    @Test func balancesPageSizeAcrossThreeSources() async throws {
        let repository = RecordingRepository()
        let combined = CombinedPulseRepository(sources: [
            .init(name: "311", repository: repository),
            .init(name: "Building", repository: repository),
            .init(name: "DDOT", repository: repository)
        ])

        let page = try await combined.nearbyItems(
            coordinate: SampleData.center, radiusMiles: 0.5, days: 30, offset: 0, limit: 30
        )

        let limits = await repository.requestedLimits()
        #expect(page.nextOffset == 10)
        #expect(limits == [10, 10, 10])
    }

    @Test func returnsHealthySourcesWithoutWaitingIndefinitelyForASlowSource() async throws {
        let item = try #require(SampleData.items.first)
        let repository = CombinedPulseRepository(
            sources: [
                .init(name: "DC 311", repository: FixedRepository(result: .success(.init(items: [item], nextOffset: 1, hasMore: false)))),
                .init(name: "Slow permits", repository: DelayedRepository())
            ],
            sourceTimeout: .milliseconds(250)
        )

        let page = try await repository.nearbyItems(
            coordinate: SampleData.center, radiusMiles: 0.5, days: 30, offset: 0, limit: 30
        )

        #expect(page.items == [item])
        #expect(page.warnings == ["Slow permits records are temporarily unavailable."])
    }
}

private struct FixedRepository: PulseRepositoryProtocol {
    let result: Result<PulsePage, Error>

    func nearbyItems(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int, offset: Int, limit: Int) async throws -> PulsePage {
        try result.get()
    }
}

private enum TestFailure: Error { case expected }

private actor RecordingRepository: PulseRepositoryProtocol {
    private var limits: [Int] = []

    func nearbyItems(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int, offset: Int, limit: Int) async throws -> PulsePage {
        limits.append(limit)
        return .init(items: [], nextOffset: offset, hasMore: false)
    }

    func requestedLimits() -> [Int] { limits.sorted() }
}

private struct DelayedRepository: PulseRepositoryProtocol {
    func nearbyItems(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int, offset: Int, limit: Int) async throws -> PulsePage {
        try await Task.sleep(for: .seconds(1))
        return .init(items: [], nextOffset: offset, hasMore: false)
    }
}

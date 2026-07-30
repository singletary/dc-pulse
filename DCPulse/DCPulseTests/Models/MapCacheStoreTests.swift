import Foundation
import Testing
@testable import DCPulse

@MainActor
struct MapCacheStoreTests {
    @Test func contextsUseRoundedCentersAndKeepSearchOptionsDistinct() throws {
        let first = try #require(PulseItem.Coordinate(latitude: 38.90721, longitude: -77.03691))
        let sameBucket = try #require(PulseItem.Coordinate(latitude: 38.90719, longitude: -77.03689))
        let nextBucket = try #require(PulseItem.Coordinate(latitude: 38.9082, longitude: -77.0369))

        #expect(context(first) == context(sameBucket))
        #expect(context(first) != context(nextBucket))
        #expect(context(first) != context(first, radiusMiles: 1))
        #expect(context(first) != context(first, periodDays: 90))
    }

    @Test func savesMultipleContextsAndReturnsTheMostRecent() async throws {
        let clock = TestClock()
        let store = makeStore(now: { clock.now })
        let first = record(id: 1, savedAt: clock.now, itemCount: 10)
        try await store.save(first)
        clock.advance(by: 60)
        let second = record(id: 2, savedAt: clock.now, itemCount: 20)
        try await store.save(second)

        #expect(await store.record(for: first.context) == first)
        #expect(await store.record(for: second.context) == second)
        #expect(await store.mostRecentRecord() == second)
    }

    @Test func evictsOldestEntriesAndCapsTotalItemCount() async throws {
        let clock = TestClock()
        let store = makeStore(
            policy: .init(
                maximumEntries: 2,
                maximumTotalItems: 25,
                maximumTotalBytes: 1_024,
                maximumAge: 3_600
            ),
            now: { clock.now }
        )
        let first = record(id: 1, savedAt: clock.now, itemCount: 10)
        try await store.save(first)
        clock.advance(by: 1)
        let second = record(id: 2, savedAt: clock.now, itemCount: 10)
        try await store.save(second)
        clock.advance(by: 1)
        let third = record(id: 3, savedAt: clock.now, itemCount: 15)
        try await store.save(third)

        #expect(await store.record(for: first.context) == nil)
        #expect(await store.record(for: second.context) == second)
        #expect(await store.record(for: third.context) == third)
    }

    @Test func expiredAndCorruptArchivesRecoverAsEmpty() async throws {
        let clock = TestClock()
        let fileURL = temporaryFileURL()
        let store = FileBackedMapCacheStore(
            fileURL: fileURL,
            policy: .init(
                maximumEntries: 2,
                maximumTotalItems: 20,
                maximumTotalBytes: 1_024,
                maximumAge: 60
            ),
            now: { clock.now }
        )
        let expired = record(id: 1, savedAt: clock.now, itemCount: 5)
        try await store.save(expired)
        clock.advance(by: 61)
        #expect(await store.mostRecentRecord() == nil)

        try Data("not-json".utf8).write(to: fileURL, options: .atomic)
        #expect(await store.mostRecentRecord() == nil)

        let recovered = record(id: 2, savedAt: clock.now, itemCount: 5)
        try await store.save(recovered)
        #expect(await store.mostRecentRecord() == recovered)
    }

    @Test func rejectsInvalidOrUnboundedRecords() async {
        let store = makeStore(
            policy: .init(
                maximumEntries: 2,
                maximumTotalItems: 10,
                maximumTotalBytes: 10,
                maximumAge: 60
            )
        )

        await #expect(throws: MapCacheStoreError.invalidItemCount) {
            try await store.save(record(id: 1, itemCount: -1))
        }
        await #expect(throws: MapCacheStoreError.recordExceedsItemLimit) {
            try await store.save(record(id: 2, itemCount: 11))
        }
        await #expect(throws: MapCacheStoreError.recordExceedsByteLimit) {
            let oversized = MapCacheRecord(
                context: record(id: 3, itemCount: 1).context,
                savedAt: Date(timeIntervalSince1970: 1_000),
                itemCount: 1,
                payload: Data(repeating: 0, count: 11)
            )
            try await store.save(oversized)
        }
        await #expect(throws: MapCacheStoreError.recordOutsideRetentionWindow) {
            try await store.save(record(
                id: 4,
                savedAt: Date(timeIntervalSince1970: 1_001),
                itemCount: 1
            ))
        }
    }

    @Test func rejectsRecordsFromAStaleSchemaGeneration() async throws {
        let store = makeStore()
        let staleContext = MapCacheContext(
            coordinate: SampleData.center,
            radiusMiles: 0.5,
            periodDays: 30,
            generation: MapCacheContext.schemaGeneration - 1
        )
        try await store.save(MapCacheRecord(
            context: staleContext,
            savedAt: Date(timeIntervalSince1970: 1_000),
            itemCount: 1,
            payload: Data("stale".utf8)
        ))

        #expect(await store.record(for: staleContext) == nil)
        #expect(await store.mostRecentRecord() == nil)
    }

    private func makeStore(
        policy: MapCachePolicy = .init(
            maximumEntries: 6,
            maximumTotalItems: 3_600,
            maximumTotalBytes: 16 * 1_024 * 1_024,
            maximumAge: 86_400
        ),
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000) }
    ) -> FileBackedMapCacheStore {
        FileBackedMapCacheStore(
            fileURL: temporaryFileURL(),
            policy: policy,
            now: now
        )
    }

    private func context(
        _ coordinate: PulseItem.Coordinate,
        radiusMiles: Double = 0.5,
        periodDays: Int = 30
    ) -> MapCacheContext {
        MapCacheContext(
            coordinate: coordinate,
            radiusMiles: radiusMiles,
            periodDays: periodDays
        )
    }

    private func record(
        id: Double,
        savedAt: Date = Date(timeIntervalSince1970: 1_000),
        itemCount: Int
    ) -> MapCacheRecord {
        let coordinate = PulseItem.Coordinate(
            latitude: 38.90 + id / 1_000,
            longitude: -77.04
        )!
        return MapCacheRecord(
            context: context(coordinate),
            savedAt: savedAt,
            itemCount: itemCount,
            payload: Data("record-\(id)".utf8)
        )
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("map-cache.json", isDirectory: false)
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_000)

    var now: Date {
        lock.withLock { value }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { value = value.addingTimeInterval(interval) }
    }
}

import Foundation
import Testing
@testable import DCPulse

@MainActor
struct PulseObservationRecordTests {
    @Test func updatesMutableSnapshotWithoutChangingIdentityOrFirstSeenDate() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let firstSeen = Date(timeIntervalSince1970: 100)
        let active = item(status: .active, coordinate: coordinate)
        let record = PulseObservationRecord(item: active, observedAt: firstSeen)

        let snapshot = record.update(
            from: item(status: .resolved, coordinate: coordinate),
            observedAt: firstSeen.addingTimeInterval(60)
        )

        #expect(record.stableKey == WatchedPulseItem.stableKey(for: active.id))
        #expect(record.firstObservedAt == firstSeen)
        #expect(record.lastObservedAt == firstSeen.addingTimeInterval(60))
        #expect(record.currentState.status == .resolved)
        #expect(snapshot?.previousStatus == .active)
        #expect(snapshot?.status == .resolved)
    }

    @Test func unchangedAndAgeDerivedStatusesDoNotCreateHistory() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let firstSeen = Date(timeIntervalSince1970: 100)
        let record = PulseObservationRecord(
            item: item(status: .new, coordinate: coordinate),
            observedAt: firstSeen
        )

        let unchanged = record.update(
            from: item(status: .new, coordinate: coordinate),
            observedAt: firstSeen.addingTimeInterval(60)
        )
        let aged = record.update(
            from: item(status: .active, coordinate: coordinate),
            observedAt: firstSeen.addingTimeInterval(120)
        )

        #expect(unchanged == nil)
        #expect(aged == nil)
        #expect(record.currentState.status == .active)
        #expect(record.lastObservedAt == firstSeen.addingTimeInterval(120))
    }

    @Test func persistedSnapshotKeepsTransitionContextSeparateFromCurrentIndex() throws {
        let observedAt = Date(timeIntervalSince1970: 200)
        let sourceUpdatedAt = Date(timeIntervalSince1970: 180)
        let record = PulseStateSnapshotRecord(snapshot: PulseStateSnapshot(
            stableKey: "serviceRequests311:311-1",
            source: .serviceRequests311,
            category: "Rodent Inspection",
            previousStatus: .active,
            status: .resolved,
            sourceUpdatedAt: sourceUpdatedAt,
            observedAt: observedAt
        ))

        let snapshot = try #require(record.snapshot)
        #expect(snapshot.previousStatus == .active)
        #expect(snapshot.status == .resolved)
        #expect(snapshot.sourceUpdatedAt == sourceUpdatedAt)
        #expect(snapshot.observedAt == observedAt)
        #expect(record.schemaVersion == PulseHistoryMaintenance.currentSchemaVersion)
    }

    @Test func migratesLegacyHistoryAndPrunesOnlyRecordsOlderThanOneYear() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let recentLegacy = snapshotRecord(
            stableKey: "serviceRequests311:recent",
            observedAt: now.addingTimeInterval(-PulseHistoryMaintenance.retentionInterval)
        )
        recentLegacy.schemaVersion = nil
        let futureVersion = snapshotRecord(
            stableKey: "serviceRequests311:future",
            observedAt: now.addingTimeInterval(-PulseHistoryMaintenance.retentionInterval - 60)
        )
        futureVersion.schemaVersion = PulseHistoryMaintenance.currentSchemaVersion + 1
        let expired = snapshotRecord(
            stableKey: "serviceRequests311:expired",
            observedAt: now.addingTimeInterval(-PulseHistoryMaintenance.retentionInterval - 1)
        )
        var deletedKeys: [String] = []

        let result = PulseHistoryMaintenance.apply(
            to: [recentLegacy, futureVersion, expired],
            now: now
        ) { deletedKeys.append($0.stableKey) }

        #expect(result == .init(migratedCount: 1, deletedCount: 1))
        #expect(recentLegacy.schemaVersion == PulseHistoryMaintenance.currentSchemaVersion)
        #expect(futureVersion.schemaVersion == PulseHistoryMaintenance.currentSchemaVersion + 1)
        #expect(deletedKeys == [expired.stableKey])
    }

    private func snapshotRecord(stableKey: String, observedAt: Date) -> PulseStateSnapshotRecord {
        PulseStateSnapshotRecord(snapshot: PulseStateSnapshot(
            stableKey: stableKey,
            source: .serviceRequests311,
            category: "Rodent Inspection",
            previousStatus: .active,
            status: .resolved,
            sourceUpdatedAt: nil,
            observedAt: observedAt
        ))
    }

    private func item(status: PulseItem.Status, coordinate: PulseItem.Coordinate) -> PulseItem {
        PulseItem(
            id: .init(source: .serviceRequests311, sourceIdentifier: "311-1"),
            category: "Rodent Inspection", subtype: nil, title: "Rodent request", summary: nil,
            status: status, openedAt: Date(timeIntervalSince1970: 50), updatedAt: nil,
            closedAt: nil, coordinate: coordinate, address: nil, wardOrNeighborhood: nil,
            responsibleAgency: nil, sourceAttributes: [], sourceURL: nil
        )
    }
}

import Foundation
import SwiftData

@Model
final class PulseObservationRecord {
    @Attribute(.unique) var stableKey: String
    var sourceRawValue: String
    var category: String
    var statusRawValue: String
    var openedAt: Date
    var updatedAt: Date?
    var latitude: Double?
    var longitude: Double?
    var firstObservedAt: Date
    var lastObservedAt: Date

    @MainActor init(item: PulseItem, observedAt: Date = .now) {
        stableKey = WatchedPulseItem.stableKey(for: item.id)
        sourceRawValue = item.id.source.rawValue
        category = item.category
        statusRawValue = item.status.rawValue
        openedAt = item.openedAt
        updatedAt = item.updatedAt
        latitude = item.coordinate?.latitude
        longitude = item.coordinate?.longitude
        firstObservedAt = observedAt
        lastObservedAt = observedAt
    }

    @MainActor @discardableResult
    func update(from item: PulseItem, observedAt: Date = .now) -> PulseStateSnapshot? {
        let previousStatus = PulseItem.Status(rawValue: statusRawValue)
        category = item.category
        statusRawValue = item.status.rawValue
        openedAt = item.openedAt
        updatedAt = item.updatedAt
        latitude = item.coordinate?.latitude
        longitude = item.coordinate?.longitude
        lastObservedAt = observedAt

        guard let previousStatus,
              item.status.isNotificationWorthyTransition(from: previousStatus) else { return nil }
        return PulseStateSnapshot(item: item, previousStatus: previousStatus, observedAt: observedAt)
    }

    @MainActor var currentState: PulseObservedState {
        PulseObservedState(
            stableKey: stableKey,
            source: PulseItem.Source(rawValue: sourceRawValue),
            category: category,
            status: PulseItem.Status(rawValue: statusRawValue),
            openedAt: openedAt,
            coordinate: latitude.flatMap { latitude in
                longitude.flatMap { PulseItem.Coordinate(latitude: latitude, longitude: $0) }
            }
        )
    }
}

struct PulseObservedState: Hashable, Sendable {
    let stableKey: String
    let source: PulseItem.Source?
    let category: String
    let status: PulseItem.Status?
    let openedAt: Date
    let coordinate: PulseItem.Coordinate?
}

struct PulseStateSnapshot: Hashable, Sendable {
    let stableKey: String
    let source: PulseItem.Source
    let category: String
    let previousStatus: PulseItem.Status
    let status: PulseItem.Status
    let sourceUpdatedAt: Date?
    let observedAt: Date

    init(item: PulseItem, previousStatus: PulseItem.Status, observedAt: Date) {
        stableKey = WatchedPulseItem.stableKey(for: item.id)
        source = item.id.source
        category = item.category
        self.previousStatus = previousStatus
        status = item.status
        sourceUpdatedAt = item.updatedAt
        self.observedAt = observedAt
    }

    init(
        stableKey: String,
        source: PulseItem.Source,
        category: String,
        previousStatus: PulseItem.Status,
        status: PulseItem.Status,
        sourceUpdatedAt: Date?,
        observedAt: Date
    ) {
        self.stableKey = stableKey
        self.source = source
        self.category = category
        self.previousStatus = previousStatus
        self.status = status
        self.sourceUpdatedAt = sourceUpdatedAt
        self.observedAt = observedAt
    }
}

@Model
final class PulseStateSnapshotRecord {
    var stableKey: String
    var sourceRawValue: String
    var category: String
    var previousStatusRawValue: String
    var statusRawValue: String
    var sourceUpdatedAt: Date?
    var observedAt: Date

    @MainActor init(snapshot: PulseStateSnapshot) {
        stableKey = snapshot.stableKey
        sourceRawValue = snapshot.source.rawValue
        category = snapshot.category
        previousStatusRawValue = snapshot.previousStatus.rawValue
        statusRawValue = snapshot.status.rawValue
        sourceUpdatedAt = snapshot.sourceUpdatedAt
        observedAt = snapshot.observedAt
    }

    @MainActor var snapshot: PulseStateSnapshot? {
        guard let source = PulseItem.Source(rawValue: sourceRawValue),
              let previousStatus = PulseItem.Status(rawValue: previousStatusRawValue),
              let status = PulseItem.Status(rawValue: statusRawValue) else { return nil }
        return PulseStateSnapshot(
            stableKey: stableKey,
            source: source,
            category: category,
            previousStatus: previousStatus,
            status: status,
            sourceUpdatedAt: sourceUpdatedAt,
            observedAt: observedAt
        )
    }
}

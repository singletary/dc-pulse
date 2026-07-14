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

    @MainActor func update(from item: PulseItem, observedAt: Date = .now) {
        category = item.category
        statusRawValue = item.status.rawValue
        openedAt = item.openedAt
        updatedAt = item.updatedAt
        latitude = item.coordinate?.latitude
        longitude = item.coordinate?.longitude
        lastObservedAt = observedAt
    }

    @MainActor var observation: PulseObservation {
        PulseObservation(
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

struct PulseObservation: Hashable, Sendable {
    let stableKey: String
    let source: PulseItem.Source?
    let category: String
    let status: PulseItem.Status?
    let openedAt: Date
    let coordinate: PulseItem.Coordinate?
}

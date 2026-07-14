import Foundation
import SwiftData

@Model
final class WatchedPulseItem {
    @Attribute(.unique) var stableKey: String
    var itemData: Data
    var statusRawValue: String
    var previousStatusRawValue: String?
    var watchedAt: Date
    var lastSeenAt: Date
    var statusChangedAt: Date?

    @MainActor init(item: PulseItem, now: Date = .now) {
        stableKey = Self.stableKey(for: item.id)
        itemData = (try? JSONEncoder().encode(item)) ?? Data()
        statusRawValue = item.status.rawValue
        watchedAt = now
        lastSeenAt = now
    }

    @MainActor var item: PulseItem? { try? JSONDecoder().decode(PulseItem.self, from: itemData) }

    var hasUnseenStatusChange: Bool { statusChangedAt != nil }

    @MainActor func update(from item: PulseItem, now: Date = .now) {
        if statusRawValue != item.status.rawValue {
            previousStatusRawValue = statusRawValue
            statusRawValue = item.status.rawValue
            statusChangedAt = now
        }
        itemData = (try? JSONEncoder().encode(item)) ?? itemData
        lastSeenAt = now
    }

    @MainActor func markStatusChangeSeen() {
        statusChangedAt = nil
        previousStatusRawValue = nil
    }

    @MainActor static func stableKey(for id: PulseItem.ID) -> String {
        "\(id.source.rawValue):\(id.sourceIdentifier)"
    }
}

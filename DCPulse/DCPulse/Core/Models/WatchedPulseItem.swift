import Foundation
import SwiftData

@Model
final class WatchedPulseItem {
    enum Origin: String, Codable, Sendable { case explicit, automatic }

    @Attribute(.unique) var stableKey: String
    var itemData: Data
    var statusRawValue: String
    var previousStatusRawValue: String?
    var watchedAt: Date
    var lastSeenAt: Date
    var statusChangedAt: Date?
    /// Optional fields preserve lightweight migration for existing on-device stores.
    var originRawValue: String?
    var terminalAt: Date?
    var archivedAt: Date?

    @MainActor init(item: PulseItem, origin: Origin = .explicit, now: Date = .now) {
        stableKey = Self.stableKey(for: item.id)
        itemData = (try? JSONEncoder().encode(item)) ?? Data()
        statusRawValue = item.status.rawValue
        watchedAt = now
        lastSeenAt = now
        originRawValue = origin.rawValue
        terminalAt = item.status == .resolved ? now : nil
    }

    @MainActor var item: PulseItem? { try? JSONDecoder().decode(PulseItem.self, from: itemData) }

    var hasUnseenStatusChange: Bool { statusChangedAt != nil }
    var origin: Origin { Origin(rawValue: originRawValue ?? "") ?? .explicit }
    var isArchived: Bool { archivedAt != nil }

    @MainActor func update(from item: PulseItem, now: Date = .now) {
        if statusRawValue != item.status.rawValue {
            if let previous = PulseItem.Status(rawValue: statusRawValue),
               item.status.isNotificationWorthyTransition(from: previous) {
                previousStatusRawValue = statusRawValue
                statusChangedAt = now
            }
            statusRawValue = item.status.rawValue
            if item.status == .resolved {
                terminalAt = now
            } else {
                terminalAt = nil
            }
        }
        itemData = (try? JSONEncoder().encode(item)) ?? itemData
        lastSeenAt = now
    }

    @MainActor @discardableResult
    func archiveIfGracePeriodExpired(
        now: Date = .now,
        explicitGracePeriod: TimeInterval? = WatchLifecyclePolicy.defaultExplicitGracePeriod
    ) -> Bool {
        if terminalAt == nil, statusRawValue == PulseItem.Status.resolved.rawValue {
            terminalAt = lastSeenAt
        }
        guard archivedAt == nil, let terminalAt,
              let gracePeriod = WatchLifecyclePolicy.gracePeriod(
                for: origin,
                explicitGracePeriod: explicitGracePeriod
              ),
              now.timeIntervalSince(terminalAt) >= gracePeriod else {
            return false
        }
        archivedAt = now
        return true
    }

    @MainActor func archive(now: Date = .now) {
        archivedAt = now
    }

    @MainActor func restore(now: Date = .now) {
        archivedAt = nil
        terminalAt = statusRawValue == PulseItem.Status.resolved.rawValue ? now : nil
    }

    @MainActor func markStatusChangeSeen() {
        statusChangedAt = nil
        previousStatusRawValue = nil
    }

    @MainActor static func stableKey(for id: PulseItem.ID) -> String {
        "\(id.source.rawValue):\(id.sourceIdentifier)"
    }
}

enum WatchLifecyclePolicy {
    static let defaultExplicitGracePeriod: TimeInterval = 30 * 24 * 60 * 60
    static let automaticGracePeriod: TimeInterval = 7 * 24 * 60 * 60

    static func gracePeriod(
        for origin: WatchedPulseItem.Origin,
        explicitGracePeriod: TimeInterval? = defaultExplicitGracePeriod
    ) -> TimeInterval? {
        switch origin {
        case .explicit: explicitGracePeriod
        case .automatic: automaticGracePeriod
        }
    }
}

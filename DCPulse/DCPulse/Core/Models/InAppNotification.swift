import Foundation
import SwiftData

@Model
final class InAppNotification {
    enum Kind: String, Codable, Sendable {
        case statusChanged
        case newNearbyItem
    }

    @Attribute(.unique) var eventKey: String
    var kindRawValue: String
    var title: String
    var message: String
    var createdAt: Date
    var readAt: Date?
    var itemData: Data?

    @MainActor
    init(
        eventKey: String,
        kind: Kind,
        title: String,
        message: String,
        item: PulseItem?,
        createdAt: Date = .now
    ) {
        self.eventKey = eventKey
        kindRawValue = kind.rawValue
        self.title = title
        self.message = message
        self.createdAt = createdAt
        itemData = item.flatMap { try? JSONEncoder().encode($0) }
    }

    var kind: Kind { Kind(rawValue: kindRawValue) ?? .statusChanged }
    var isUnread: Bool { readAt == nil }

    @MainActor
    var item: PulseItem? {
        guard let itemData else { return nil }
        return try? JSONDecoder().decode(PulseItem.self, from: itemData)
    }

    func markRead(at date: Date = .now) {
        guard readAt == nil else { return }
        readAt = date
    }

    @MainActor
    static func statusChange(
        item: PulseItem,
        previousStatus: PulseItem.Status,
        changedAt: Date = .now
    ) -> InAppNotification {
        let sourceDate = item.updatedAt ?? item.closedAt ?? changedAt
        let key = [
            "status",
            WatchedPulseItem.stableKey(for: item.id),
            previousStatus.rawValue,
            item.status.rawValue,
            String(sourceDate.timeIntervalSince1970)
        ].joined(separator: ":")
        var message = "\(previousStatus.displayName) → \(item.status.displayName)"
        if let address = item.address { message += " · \(address)" }
        return InAppNotification(
            eventKey: key,
            kind: .statusChanged,
            title: "Status changed · \(item.category)",
            message: message,
            item: item,
            createdAt: changedAt
        )
    }

    @MainActor
    static func newNearbyItem(item: PulseItem, discoveredAt: Date = .now) -> InAppNotification {
        let key = "nearby:\(WatchedPulseItem.stableKey(for: item.id))"
        var message = item.title
        if let address = item.address { message += " · \(address)" }
        return InAppNotification(
            eventKey: key,
            kind: .newNearbyItem,
            title: "New near home · \(item.category)",
            message: message,
            item: item,
            createdAt: discoveredAt
        )
    }
}

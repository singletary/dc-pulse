import Foundation

struct NotificationDestination: Equatable, Sendable {
    let itemID: PulseItem.ID

    init?(userInfo: [AnyHashable: Any]) {
        guard let sourceValue = userInfo["source"] as? String,
              let source = PulseItem.Source(rawValue: sourceValue),
              let identifier = userInfo["sourceIdentifier"] as? String,
              !identifier.isEmpty else { return nil }
        itemID = .init(source: source, sourceIdentifier: identifier)
    }
}

extension Notification.Name {
    static let openWatchedPulseItem = Notification.Name("dcPulse.openWatchedPulseItem")
}

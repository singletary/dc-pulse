import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class NotificationService {
    enum AuthorizationState { case unknown, notDetermined, denied, authorized }

    private enum Key {
        static let statusChangeAlertsEnabled = "dcPulse.notifications.watchedItemsEnabled"
        static let newNearbyAlertsEnabled = "dcPulse.notifications.newNearbyItemsEnabled"
    }
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    private(set) var authorizationState: AuthorizationState = .unknown
    var statusChangeAlertsEnabled: Bool {
        didSet { defaults.set(statusChangeAlertsEnabled, forKey: Key.statusChangeAlertsEnabled) }
    }
    var newNearbyAlertsEnabled: Bool {
        didSet { defaults.set(newNearbyAlertsEnabled, forKey: Key.newNearbyAlertsEnabled) }
    }

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        let legacyPreference = defaults.bool(forKey: Key.statusChangeAlertsEnabled)
        statusChangeAlertsEnabled = legacyPreference
        newNearbyAlertsEnabled = defaults.object(forKey: Key.newNearbyAlertsEnabled) as? Bool ?? legacyPreference
    }

    func refreshAuthorizationState() async {
        let settings = await center.notificationSettings()
        authorizationState = Self.state(for: settings.authorizationStatus)
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationState()
            return granted
        } catch {
            await refreshAuthorizationState()
            return false
        }
    }

    func notifyStatusChange(
        item: PulseItem,
        previousStatus: PulseItem.Status,
        changedAt: Date = .now
    ) async {
        guard statusChangeAlertsEnabled, authorizationState == .authorized else { return }
        let request = WatchedItemNotification.request(
            item: item,
            previousStatus: previousStatus,
            changedAt: changedAt
        )
        try? await center.add(request)
    }

    func notifyNewNearbyItem(item: PulseItem, discoveredAt: Date = .now) async {
        guard newNearbyAlertsEnabled, authorizationState == .authorized else { return }
        try? await center.add(NewNearbyItemNotification.request(item: item, discoveredAt: discoveredAt))
    }

    static func state(for status: UNAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .unknown
        }
    }
}

enum NewNearbyItemNotification {
    static func request(item: PulseItem, discoveredAt: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "New near Home · \(item.category)"
        content.body = "Open DC Pulse for public record details."
        content.sound = .default
        content.userInfo = [
            "source": item.id.source.rawValue,
            "sourceIdentifier": item.id.sourceIdentifier
        ]
        let identifier = "nearby.\(WatchedPulseItem.stableKey(for: item.id)).\(discoveredAt.timeIntervalSince1970)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }
}

enum WatchedItemNotification {
    static func request(
        item: PulseItem,
        previousStatus: PulseItem.Status,
        changedAt: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Status changed · \(item.category)"
        content.body = "\(previousStatus.displayName) → \(item.status.displayName)"
        content.sound = .default
        content.userInfo = [
            "source": item.id.source.rawValue,
            "sourceIdentifier": item.id.sourceIdentifier
        ]
        let identifier = "watch.\(WatchedPulseItem.stableKey(for: item.id)).\(changedAt.timeIntervalSince1970)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }
}

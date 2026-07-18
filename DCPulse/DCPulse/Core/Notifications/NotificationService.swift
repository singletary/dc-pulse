import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class NotificationService {
    enum AuthorizationState { case unknown, notDetermined, denied, authorized }

    private enum Key { static let alertsEnabled = "dcPulse.notifications.watchedItemsEnabled" }
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    private(set) var authorizationState: AuthorizationState = .unknown
    var alertsEnabled: Bool {
        didSet { defaults.set(alertsEnabled, forKey: Key.alertsEnabled) }
    }

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        alertsEnabled = defaults.bool(forKey: Key.alertsEnabled)
    }

    func refreshAuthorizationState() async {
        let settings = await center.notificationSettings()
        authorizationState = Self.state(for: settings.authorizationStatus)
        if authorizationState == .denied { alertsEnabled = false }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationState()
            alertsEnabled = granted
            return granted
        } catch {
            await refreshAuthorizationState()
            alertsEnabled = false
            return false
        }
    }

    func notifyStatusChange(
        item: PulseItem,
        previousStatus: PulseItem.Status,
        changedAt: Date = .now
    ) async {
        guard alertsEnabled, authorizationState == .authorized else { return }
        let request = WatchedItemNotification.request(
            item: item,
            previousStatus: previousStatus,
            changedAt: changedAt
        )
        try? await center.add(request)
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

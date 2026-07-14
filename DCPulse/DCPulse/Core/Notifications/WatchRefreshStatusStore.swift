import Foundation
import Observation

@MainActor @Observable
final class WatchRefreshStatusStore {
    private enum Key {
        static let lastAttempt = "dcPulse.watchRefresh.lastAttempt"
        static let lastSuccess = "dcPulse.watchRefresh.lastSuccess"
    }

    private let defaults: UserDefaults
    private(set) var lastAttempt: Date?
    private(set) var lastSuccess: Date?
    private(set) var isRefreshing = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastAttempt = defaults.object(forKey: Key.lastAttempt) as? Date
        lastSuccess = defaults.object(forKey: Key.lastSuccess) as? Date
    }

    func begin(at date: Date = .now) {
        isRefreshing = true
        lastAttempt = date
        defaults.set(date, forKey: Key.lastAttempt)
    }

    func complete(success: Bool, at date: Date = .now) {
        isRefreshing = false
        guard success else { return }
        lastSuccess = date
        defaults.set(date, forKey: Key.lastSuccess)
    }
}

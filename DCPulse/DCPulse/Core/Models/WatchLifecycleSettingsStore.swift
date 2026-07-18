import Foundation
import Observation

@MainActor @Observable
final class WatchLifecycleSettingsStore {
    enum GracePeriod: Int, CaseIterable, Identifiable, Sendable {
        case sevenDays = 7
        case thirtyDays = 30
        case ninetyDays = 90
        case never = 0

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .sevenDays: "After 7 days"
            case .thirtyDays: "After 30 days"
            case .ninetyDays: "After 90 days"
            case .never: "Never"
            }
        }

        var timeInterval: TimeInterval? {
            guard self != .never else { return nil }
            return TimeInterval(rawValue * 24 * 60 * 60)
        }
    }

    private enum Key {
        static let explicitWatchGraceDays = "dcPulse.watchLifecycle.explicitGraceDays"
    }

    private let defaults: UserDefaults
    var explicitWatchGracePeriod: GracePeriod {
        didSet { defaults.set(explicitWatchGracePeriod.rawValue, forKey: Key.explicitWatchGraceDays) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedValue = defaults.object(forKey: Key.explicitWatchGraceDays) as? Int
        explicitWatchGracePeriod = storedValue.flatMap(GracePeriod.init(rawValue:)) ?? .thirtyDays
    }
}

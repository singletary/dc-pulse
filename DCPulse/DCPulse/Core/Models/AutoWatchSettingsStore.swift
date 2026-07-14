import Foundation
import Observation

@MainActor @Observable
final class AutoWatchSettingsStore {
    enum Distance: Double, CaseIterable, Identifiable {
        case veryClose = 0.1
        case nearby = 0.25

        var id: Double { rawValue }
        var label: String {
            switch self {
            case .veryClose: "Very close · 0.1 mile"
            case .nearby: "Nearby · 0.25 mile"
            }
        }
    }

    private enum Key {
        static let enabled = "dcPulse.autoWatch.enabled"
        static let distance = "dcPulse.autoWatch.distanceMiles"
    }

    private let defaults: UserDefaults
    var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Key.enabled) } }
    var distance: Distance { didSet { defaults.set(distance.rawValue, forKey: Key.distance) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Key.enabled)
        distance = Distance(rawValue: defaults.double(forKey: Key.distance)) ?? .veryClose
    }
}

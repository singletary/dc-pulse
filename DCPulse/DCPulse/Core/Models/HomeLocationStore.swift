import Foundation
import Observation

@MainActor @Observable
final class HomeLocationStore {
    private struct SavedHome: Codable {
        let name: String
        let address: String
        let coordinate: PulseItem.Coordinate
    }

    private enum Key { static let home = "dcPulse.savedHome" }
    private let defaults: UserDefaults

    private(set) var name: String?
    private(set) var address: String?
    private(set) var coordinate: PulseItem.Coordinate?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Key.home),
              let home = try? JSONDecoder().decode(SavedHome.self, from: data) else { return }
        name = home.name
        address = home.address
        coordinate = home.coordinate
    }

    func save(name: String = "Home", address: String, coordinate: PulseItem.Coordinate) {
        let home = SavedHome(name: name, address: address, coordinate: coordinate)
        guard let data = try? JSONEncoder().encode(home) else { return }
        defaults.set(data, forKey: Key.home)
        self.name = name
        self.address = address
        self.coordinate = coordinate
    }

    func remove() {
        defaults.removeObject(forKey: Key.home)
        name = nil
        address = nil
        coordinate = nil
    }
}

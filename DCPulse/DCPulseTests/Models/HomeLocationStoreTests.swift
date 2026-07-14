import Foundation
import Testing
@testable import DCPulse

@MainActor
struct HomeLocationStoreTests {
    @Test func persistsAndRemovesHomeLocation() throws {
        let suite = "HomeLocationStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))

        let store = HomeLocationStore(defaults: defaults)
        store.save(address: "9999 Example Avenue NW, Washington, DC", coordinate: coordinate)

        let restored = HomeLocationStore(defaults: defaults)
        #expect(restored.address == "9999 Example Avenue NW, Washington, DC")
        #expect(restored.coordinate == coordinate)

        restored.remove()
        #expect(restored.address == nil)
        #expect(HomeLocationStore(defaults: defaults).address == nil)
    }
}

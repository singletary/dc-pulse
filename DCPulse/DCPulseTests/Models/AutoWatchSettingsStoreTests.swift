import Foundation
import Testing
@testable import DCPulse

@MainActor
struct AutoWatchSettingsStoreTests {
    @Test func persistsOptInAndDistance() throws {
        let suite = "AutoWatchSettingsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let settings = AutoWatchSettingsStore(defaults: defaults)
        #expect(!settings.isEnabled)
        #expect(settings.distance == .veryClose)
        settings.isEnabled = true
        settings.distance = .nearby

        let restored = AutoWatchSettingsStore(defaults: defaults)
        #expect(restored.isEnabled)
        #expect(restored.distance == .nearby)
    }
}

import Foundation
import Testing
@testable import DCPulse

@MainActor
struct WatchLifecycleSettingsStoreTests {
    @Test func defaultsToThirtyDaysAndPersistsEveryChoice() throws {
        let suite = "WatchLifecycleSettingsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let settings = WatchLifecycleSettingsStore(defaults: defaults)
        #expect(settings.explicitWatchGracePeriod == .thirtyDays)

        settings.explicitWatchGracePeriod = .ninetyDays
        #expect(WatchLifecycleSettingsStore(defaults: defaults).explicitWatchGracePeriod == .ninetyDays)

        settings.explicitWatchGracePeriod = .never
        #expect(WatchLifecycleSettingsStore(defaults: defaults).explicitWatchGracePeriod == .never)
        #expect(settings.explicitWatchGracePeriod.timeInterval == nil)
    }

    @Test func automaticWatchesIgnoreTheExplicitNeverPreference() {
        #expect(WatchLifecyclePolicy.gracePeriod(for: .explicit, explicitGracePeriod: nil) == nil)
        #expect(
            WatchLifecyclePolicy.gracePeriod(for: .automatic, explicitGracePeriod: nil)
                == WatchLifecyclePolicy.automaticGracePeriod
        )
    }
}

import Foundation
import Testing
@testable import DCPulse

@MainActor
struct WatchRefreshStatusStoreTests {
    @Test func persistsAttemptsAndOnlySuccessfulCompletion() {
        let defaults = UserDefaults(suiteName: "WatchRefreshStatusStoreTests.\(UUID().uuidString)")!
        let attempt = Date(timeIntervalSince1970: 100)
        let success = Date(timeIntervalSince1970: 200)
        let store = WatchRefreshStatusStore(defaults: defaults)

        store.begin(at: attempt)
        store.complete(success: false, at: success)
        #expect(store.lastAttempt == attempt)
        #expect(store.lastSuccess == nil)

        store.complete(success: true, at: success)
        let restored = WatchRefreshStatusStore(defaults: defaults)
        #expect(restored.lastAttempt == attempt)
        #expect(restored.lastSuccess == success)
    }
}

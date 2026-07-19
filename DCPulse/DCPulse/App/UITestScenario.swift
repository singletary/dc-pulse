#if DEBUG
import Foundation
import SwiftData

@MainActor
enum UITestScenario {
    private static let environmentKey = "DCPULSE_UI_TEST_SCENARIO"
    private static let watchRestorationScenario = "watch-restoration"

    static func prepareIfRequested(in modelContext: ModelContext) {
        guard ProcessInfo.processInfo.environment[environmentKey] == watchRestorationScenario else { return }

        do {
            for watched in try modelContext.fetch(FetchDescriptor<WatchedPulseItem>()) {
                modelContext.delete(watched)
            }

            guard let item = SampleData.items.first(where: { $0.id.source == .serviceRequests311 }) else { return }
            let watched = WatchedPulseItem(item: item, now: Date(timeIntervalSince1970: 1_700_000_000))
            watched.archive(now: Date(timeIntervalSince1970: 1_700_086_400))
            modelContext.insert(watched)
            try modelContext.save()
        } catch {
            assertionFailure("Unable to prepare the watch-restoration UI test: \(error)")
        }
    }
}
#endif

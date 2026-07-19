#if DEBUG
import Foundation
import SwiftData

@MainActor
enum UITestScenario {
    private static let environmentKey = "DCPULSE_UI_TEST_SCENARIO"

    private enum Scenario: String {
        case watchRestoration = "watch-restoration"
        case followedPlaceNavigation = "followed-place-navigation"
    }

    static func prepareIfRequested(in modelContext: ModelContext) {
        guard let value = ProcessInfo.processInfo.environment[environmentKey],
              let scenario = Scenario(rawValue: value) else { return }

        switch scenario {
        case .watchRestoration:
            prepareWatchRestoration(in: modelContext)
        case .followedPlaceNavigation:
            prepareFollowedPlaceNavigation(in: modelContext)
        }
    }

    private static func prepareWatchRestoration(in modelContext: ModelContext) {
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

    private static func prepareFollowedPlaceNavigation(in modelContext: ModelContext) {
        do {
            for place in try modelContext.fetch(FetchDescriptor<FollowedPlace>()) {
                modelContext.delete(place)
            }
            modelContext.insert(FollowedPlace(
                name: "Saved Test Place",
                address: "Synthetic saved place, Washington, DC",
                coordinate: SampleData.center,
                followedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ))
            try modelContext.save()
        } catch {
            assertionFailure("Unable to prepare the followed-place UI test: \(error)")
        }
    }
}
#endif

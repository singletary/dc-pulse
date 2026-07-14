import CoreLocation
import Foundation

enum NoteworthyItemRanker {
    static let nearbyHomeDistanceMeters = 160.934 // One tenth of a statute mile.

    static func rank(
        _ items: [PulseItem],
        homeCoordinate: PulseItem.Coordinate?
    ) -> [PulseItem] {
        items.sorted { left, right in
            let leftRank = rank(for: left, homeCoordinate: homeCoordinate)
            let rightRank = rank(for: right, homeCoordinate: homeCoordinate)
            if leftRank != rightRank { return leftRank > rightRank }
            return left.openedAt > right.openedAt
        }
    }

    private static func rank(
        for item: PulseItem,
        homeCoordinate: PulseItem.Coordinate?
    ) -> Int {
        let statusRank = switch item.status {
        case .new: 2
        case .active: 1
        case .resolved, .unknown: 0
        }

        // Nearby permits can materially affect a saved home, so surface them before
        // ordinary nearby requests while retaining recency as the tie breaker.
        return (isPermitNearHome(item, homeCoordinate: homeCoordinate) ? 10 : 0) + statusRank
    }

    static func isPermitNearHome(
        _ item: PulseItem,
        homeCoordinate: PulseItem.Coordinate?
    ) -> Bool {
        guard item.id.source != .serviceRequests311,
              let homeCoordinate,
              let itemCoordinate = item.coordinate else { return false }
        let home = CLLocation(latitude: homeCoordinate.latitude, longitude: homeCoordinate.longitude)
        let location = CLLocation(latitude: itemCoordinate.latitude, longitude: itemCoordinate.longitude)
        return home.distance(from: location) <= nearbyHomeDistanceMeters
    }
}

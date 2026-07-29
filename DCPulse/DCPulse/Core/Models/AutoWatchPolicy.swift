import CoreLocation
import Foundation

enum AutoWatchPolicy {
    static let newNearbyNotificationDistanceMiles = 0.1

    static func candidates(
        from items: [PulseItem],
        home: PulseItem.Coordinate,
        distanceMiles: Double,
        excluding watchedKeys: Set<String>
    ) -> [PulseItem] {
        return items.filter { item in
            guard item.status == .new || item.id.source != .serviceRequests311,
                  let coordinate = item.coordinate,
                  !watchedKeys.contains(WatchedPulseItem.stableKey(for: item.id)) else { return false }
            return isWithinDistance(coordinate, of: home, distanceMiles: distanceMiles)
        }
    }

    static func isEligibleForNewNearbyNotification(
        _ item: PulseItem,
        home: PulseItem.Coordinate
    ) -> Bool {
        guard let coordinate = item.coordinate else { return false }
        return isWithinDistance(
            coordinate,
            of: home,
            distanceMiles: newNearbyNotificationDistanceMiles
        )
    }

    private static func isWithinDistance(
        _ coordinate: PulseItem.Coordinate,
        of home: PulseItem.Coordinate,
        distanceMiles: Double
    ) -> Bool {
        let homeLocation = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let itemLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return itemLocation.distance(from: homeLocation) <= distanceMiles * 1_609.344
    }
}

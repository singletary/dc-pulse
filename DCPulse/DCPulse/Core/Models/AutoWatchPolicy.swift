import CoreLocation
import Foundation

enum AutoWatchPolicy {
    static func candidates(
        from items: [PulseItem],
        home: PulseItem.Coordinate,
        distanceMiles: Double,
        excluding watchedKeys: Set<String>
    ) -> [PulseItem] {
        let homeLocation = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let maximumDistance = distanceMiles * 1_609.344

        return items.filter { item in
            guard item.status == .new || item.id.source != .serviceRequests311,
                  let coordinate = item.coordinate,
                  !watchedKeys.contains(WatchedPulseItem.stableKey(for: item.id)) else { return false }
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return location.distance(from: homeLocation) <= maximumDistance
        }
    }
}

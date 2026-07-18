import CoreLocation
import Foundation

/// Converts a device coordinate into a safe, understandable DC search context.
///
/// ArcGIS queries remain centered inside the app's supported DC envelope. A person
/// just outside the city gets the nearest usable edge; someone farther away gets
/// the same stable public fallback used when location is unavailable.
struct DCLocationRoutingPolicy: Sendable {
    enum Resolution: Equatable, Sendable {
        case current(PulseItem.Coordinate)
        case nearbyBorder(PulseItem.Coordinate)
        case defaultDC(PulseItem.Coordinate)

        var searchCoordinate: PulseItem.Coordinate {
            switch self {
            case .current(let coordinate), .nearbyBorder(let coordinate), .defaultDC(let coordinate):
                coordinate
            }
        }

        var placeName: String {
            switch self {
            case .current: "Current Location"
            case .nearbyBorder: "Near the DC Border"
            case .defaultDC: "Downtown DC"
            }
        }
    }

    static let defaultCoordinate = PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300)!

    /// A nearby Maryland or Virginia location can still be usefully routed to DC.
    /// Beyond this distance, a stable central view is less surprising than an edge.
    private let nearbyThresholdMeters: CLLocationDistance
    private let boundaryInsetDegrees: Double

    nonisolated init(
        nearbyThresholdMeters: CLLocationDistance = 25 * 1_609.344,
        boundaryInsetDegrees: Double = 0.003
    ) {
        self.nearbyThresholdMeters = nearbyThresholdMeters
        self.boundaryInsetDegrees = boundaryInsetDegrees
    }

    func resolve(_ coordinate: PulseItem.Coordinate) -> Resolution {
        guard !coordinate.isWithinDCServiceArea else { return .current(coordinate) }

        let borderCoordinate = PulseItem.Coordinate(
            latitude: min(
                max(coordinate.latitude, PulseItem.Coordinate.dcLatitudeRange.lowerBound + boundaryInsetDegrees),
                PulseItem.Coordinate.dcLatitudeRange.upperBound - boundaryInsetDegrees
            ),
            longitude: min(
                max(coordinate.longitude, PulseItem.Coordinate.dcLongitudeRange.lowerBound + boundaryInsetDegrees),
                PulseItem.Coordinate.dcLongitudeRange.upperBound - boundaryInsetDegrees
            )
        )!
        let deviceLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let borderLocation = CLLocation(
            latitude: borderCoordinate.latitude,
            longitude: borderCoordinate.longitude
        )

        return deviceLocation.distance(from: borderLocation) <= nearbyThresholdMeters
            ? .nearbyBorder(borderCoordinate)
            : .defaultDC(Self.defaultCoordinate)
    }
}

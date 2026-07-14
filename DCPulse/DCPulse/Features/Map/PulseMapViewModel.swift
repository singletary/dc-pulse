import MapKit
import Observation
import SwiftUI

@Observable final class PulseMapViewModel {
    var region = MKCoordinateRegion(
        center: SampleData.center.clLocationCoordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
    )
    private(set) var centerRequestID = 0

    func center(on coordinate: PulseItem.Coordinate, radius: PulseDataStore.Radius) {
        region = MKCoordinateRegion(
            center: coordinate.clLocationCoordinate,
            span: Self.span(for: radius)
        )
        centerRequestID += 1
    }

    private static func span(for radius: PulseDataStore.Radius) -> MKCoordinateSpan {
        let delta = switch radius {
        case .quarterMile: 0.012
        case .halfMile: 0.022
        case .oneMile: 0.04
        }
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }
}

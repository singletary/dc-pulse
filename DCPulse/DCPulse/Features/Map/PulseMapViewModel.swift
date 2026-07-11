import MapKit
import Observation
import SwiftUI

@Observable final class PulseMapViewModel {
    var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: SampleData.center.clLocationCoordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
    ))
}

import CoreLocation
import MapKit
import Testing
@testable import DCPulse

@MainActor
struct PulseMapViewModelTests {
    @Test func centerUpdatesRegionAndCommandIdentity() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let viewModel = PulseMapViewModel()
        let initialRequest = viewModel.centerRequestID

        viewModel.center(on: coordinate, radius: .quarterMile)

        #expect(viewModel.centerRequestID == initialRequest + 1)
        #expect(viewModel.region.center.latitude == coordinate.latitude)
        #expect(viewModel.region.center.longitude == coordinate.longitude)
        #expect(viewModel.region.span.latitudeDelta == 0.012)
    }

    @Test func largerRadiusUsesWiderRegion() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let viewModel = PulseMapViewModel()
        viewModel.center(on: coordinate, radius: .oneMile)
        #expect(viewModel.region.span.latitudeDelta == 0.04)
    }
}

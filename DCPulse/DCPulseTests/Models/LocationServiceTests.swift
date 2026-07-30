import CoreLocation
import Testing
@testable import DCPulse

@MainActor
struct LocationServiceTests {
    @Test func authorizedRelaunchRequestsLocationAndRecoversFromOutsideDC() async {
        let manager = StubLocationManager(authorizationStatus: .authorizedWhenInUse)
        let service = LocationService(
            manager: manager,
            locationLabelResolver: StubLocationLabelResolver(label: "Near Test Place")
        )

        service.requestCurrentLocation()
        #expect(service.state == .locating)
        #expect(manager.locationRequestCount == 1)

        service.handle(location: CLLocation(latitude: 39.40, longitude: -77.04))
        guard case .outsideDC = service.state else {
            Issue.record("Expected an outside-DC resolution")
            return
        }
        #expect(service.coordinate == nil)

        service.requestCurrentLocation()
        service.handle(location: CLLocation(latitude: 38.9072, longitude: -77.0369))
        await Task.yield()

        #expect(manager.locationRequestCount == 2)
        #expect(service.state == .located)
        #expect(service.coordinate == PulseItem.Coordinate(latitude: 38.9072, longitude: -77.0369))
        #expect(service.locationLabel == "Near Test Place")
        #expect(service.updateSequence == 2)
    }

    @Test func authorizationRecoveryRequestsALaterValidLocation() {
        let manager = StubLocationManager(authorizationStatus: .denied)
        let service = LocationService(
            manager: manager,
            locationLabelResolver: StubLocationLabelResolver(label: nil)
        )

        service.requestCurrentLocation()
        #expect(service.state == .denied)
        #expect(manager.locationRequestCount == 0)

        manager.authorizationStatus = .authorizedWhenInUse
        service.handleAuthorizationChange()

        #expect(service.state == .locating)
        #expect(manager.locationRequestCount == 1)
    }

    @Test func approximateLocationRemainsAUsableCurrentContext() {
        let manager = StubLocationManager(authorizationStatus: .authorizedWhenInUse)
        let service = LocationService(
            manager: manager,
            locationLabelResolver: StubLocationLabelResolver(label: nil)
        )
        let approximate = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 38.92, longitude: -77.04),
            altitude: 0,
            horizontalAccuracy: 5_000,
            verticalAccuracy: -1,
            timestamp: .now
        )

        service.handle(location: approximate)

        #expect(service.state == .located)
        #expect(service.coordinate == PulseItem.Coordinate(latitude: 38.92, longitude: -77.04))
    }
}

@MainActor
private final class StubLocationManager: LocationManaging {
    weak var delegate: (any CLLocationManagerDelegate)?
    var desiredAccuracy = kCLLocationAccuracyBest
    var authorizationStatus: CLAuthorizationStatus
    private(set) var permissionRequestCount = 0
    private(set) var locationRequestCount = 0

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        permissionRequestCount += 1
    }

    func requestLocation() {
        locationRequestCount += 1
    }
}

private struct StubLocationLabelResolver: LocationLabelResolving {
    let label: String?

    func label(for location: CLLocation) async -> String? {
        label
    }
}

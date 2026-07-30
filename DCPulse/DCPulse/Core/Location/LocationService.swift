import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor
protocol LocationManaging: AnyObject {
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var authorizationStatus: CLAuthorizationStatus { get }

    func requestWhenInUseAuthorization()
    func requestLocation()
}

extension CLLocationManager: LocationManaging {}

@MainActor
protocol LocationLabelResolving {
    func label(for location: CLLocation) async -> String?
}

struct MapKitLocationLabelResolver: LocationLabelResolving {
    func label(for location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let mapItem = try? await request.mapItems.first else { return nil }
        if let address = mapItem.address?.shortAddress { return "Near \(address)" }
        if let name = mapItem.name { return "Near \(name)" }
        return nil
    }
}

@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle
        case requestingPermission
        case locating
        case located
        case denied
        case restricted
        case outsideDC(DCLocationRoutingPolicy.Resolution)
        case failed(String)
    }

    private let manager: any LocationManaging
    private let routingPolicy: DCLocationRoutingPolicy
    private let locationLabelResolver: any LocationLabelResolving
    private var geocodingTask: Task<Void, Never>?
    private(set) var state: State = .idle
    private(set) var coordinate: PulseItem.Coordinate?
    private(set) var updateSequence = 0
    private(set) var locationLabel: String?

    var isResolvingLocation: Bool {
        state == .requestingPermission || state == .locating
    }

    override convenience init() {
        self.init(
            manager: CLLocationManager(),
            routingPolicy: .init(),
            locationLabelResolver: MapKitLocationLabelResolver()
        )
    }

    init(
        manager: any LocationManaging,
        routingPolicy: DCLocationRoutingPolicy = .init(),
        locationLabelResolver: any LocationLabelResolving
    ) {
        self.manager = manager
        self.routingPolicy = routingPolicy
        self.locationLabelResolver = locationLabelResolver
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .requestingPermission
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            state = .locating
            manager.requestLocation()
        case .denied:
            state = .denied
        case .restricted:
            state = .restricted
        @unknown default:
            state = .failed("Location authorization is unavailable.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationChange()
    }

    func handleAuthorizationChange() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            state = .locating
            manager.requestLocation()
        case .denied: state = .denied
        case .restricted: state = .restricted
        case .notDetermined: break
        @unknown default: state = .failed("Location authorization is unavailable.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            failLocation("Your location could not be determined.")
            return
        }
        handle(location: location)
    }

    func handle(location: CLLocation) {
        guard let coordinate = PulseItem.Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
              ) else {
            failLocation("Your location could not be determined.")
            return
        }
        let resolution = routingPolicy.resolve(coordinate)
        guard case .current = resolution else {
            geocodingTask?.cancel()
            self.coordinate = nil
            locationLabel = nil
            state = .outsideDC(resolution)
            updateSequence += 1
            return
        }
        self.coordinate = coordinate
        updateSequence += 1
        state = .located
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied { state = .denied }
        else { failLocation("Your location could not be determined. Try again.") }
    }

    private func failLocation(_ message: String) {
        geocodingTask?.cancel()
        coordinate = nil
        locationLabel = nil
        state = .failed(message)
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocodingTask?.cancel()
        let expectedCoordinate = coordinate
        geocodingTask = Task { [weak self] in
            guard let self else { return }
            let label = await locationLabelResolver.label(for: location)
            guard !Task.isCancelled, coordinate == expectedCoordinate else { return }
            locationLabel = label
        }
    }
}

import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle
        case requestingPermission
        case locating
        case located
        case denied
        case restricted
        case failed(String)
    }

    private let manager: CLLocationManager
    private var geocodingRequest: MKReverseGeocodingRequest?
    private(set) var state: State = .idle
    private(set) var coordinate: PulseItem.Coordinate?
    private(set) var updateSequence = 0
    private(set) var locationLabel: String?

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
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
        guard let location = locations.last,
              let coordinate = PulseItem.Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
              ) else {
            state = .failed("Your location could not be determined.")
            return
        }
        self.coordinate = coordinate
        updateSequence += 1
        state = .located
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied { state = .denied }
        else { state = .failed("Your location could not be determined. Try again.") }
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocodingRequest?.cancel()
        guard let request = MKReverseGeocodingRequest(location: location) else { return }
        geocodingRequest = request
        Task {
            guard let mapItem = try? await request.mapItems.first else { return }
            if let address = mapItem.address?.shortAddress { locationLabel = "Near \(address)" }
            else if let name = mapItem.name { locationLabel = "Near \(name)" }
        }
    }
}

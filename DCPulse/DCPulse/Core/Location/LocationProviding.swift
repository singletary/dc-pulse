import CoreLocation

protocol LocationProviding: Sendable {
    func currentCoordinate() async throws -> CLLocationCoordinate2D
}

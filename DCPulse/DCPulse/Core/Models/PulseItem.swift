import CoreLocation
import Foundation

struct PulseItem: Identifiable, Hashable, Codable, Sendable {
    struct ID: Hashable, Codable, Sendable {
        let source: Source
        let sourceIdentifier: String
    }

    enum Source: String, Codable, CaseIterable, Sendable {
        case serviceRequests311
        case buildingPermits2026
        case ddotConstructionPermits2026

        var displayName: String {
            switch self {
            case .serviceRequests311: "311 Service Request"
            case .buildingPermits2026: "Building Permit"
            case .ddotConstructionPermits2026: "DDOT Construction Permit"
            }
        }
    }

    enum Status: String, Codable, CaseIterable, Sendable {
        case new, active, resolved, unknown

        var displayName: String { rawValue.capitalized }
    }

    struct Coordinate: Hashable, Codable, Sendable {
        let latitude: Double
        let longitude: Double

        init?(latitude: Double, longitude: Double) {
            guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
            self.latitude = latitude
            self.longitude = longitude
        }

        var clLocationCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var isWithinDCServiceArea: Bool {
            (38.79...39.00).contains(latitude) && (-77.13 ... -76.90).contains(longitude)
        }
    }

    struct SourceAttribute: Identifiable, Hashable, Codable, Sendable {
        var id: String { label }
        let label: String
        let value: String
    }

    let id: ID
    let category: String
    let subtype: String?
    let title: String
    let summary: String?
    let status: Status
    let openedAt: Date
    let updatedAt: Date?
    let closedAt: Date?
    let coordinate: Coordinate?
    let address: String?
    let wardOrNeighborhood: String?
    let responsibleAgency: String?
    let sourceAttributes: [SourceAttribute]
    let sourceURL: URL?
}

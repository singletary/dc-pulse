import CoreLocation
import Foundation

struct RestaurantInspection: Identifiable, Hashable, Sendable {
    enum MapVisibility: Equatable, Sendable {
        case highlightedByDefault
        case availableThroughFilter
    }

    enum Filter: Equatable, Sendable {
        case needsAttention
        case all
    }

    struct ID: Hashable, Sendable {
        let permitIdentifier: String
        let inspectionIdentifier: String
    }

    enum Outcome: String, Codable, Sendable {
        case passed
        case followUpRequired
        case closed
        case restored
        case unknown

        var displayName: String {
            switch self {
            case .passed: "Passed"
            case .followUpRequired: "Follow-up required"
            case .closed: "Closed by DC Health"
            case .restored: "Restored"
            case .unknown: "Result unavailable"
            }
        }
    }

    struct ViolationCounts: Hashable, Sendable {
        let priority: Int
        let priorityFoundation: Int
        let core: Int

        var total: Int { priority + priorityFoundation + core }
        var hasFoodSafetyPriority: Bool { priority > 0 || priorityFoundation > 0 }
    }

    let id: ID
    let establishmentName: String
    let address: String
    let ward: String?
    let coordinate: PulseItem.Coordinate
    let inspectionDate: Date
    let inspectionType: String
    let outcome: Outcome
    let violations: ViolationCounts
    let reportURL: URL
    let feedGeneratedAt: Date
    let attribution: String
    let sourceURL: URL

    var needsAttention: Bool {
        outcome == .closed || outcome == .followUpRequired || violations.hasFoodSafetyPriority
    }

    /// Keeps the default civic map focused on the most urgent food-safety findings.
    /// Every other inspection remains available when the restaurant layer is expanded.
    var mapVisibility: MapVisibility {
        needsAttention ? .highlightedByDefault : .availableThroughFilter
    }

    func isIncluded(in filter: Filter) -> Bool {
        switch filter {
        case .needsAttention: needsAttention
        case .all: true
        }
    }

    var attentionSummary: String {
        if outcome == .closed { return "Closed for an imminent public-health concern" }
        if violations.priority > 0 {
            return "\(violations.priority) priority violation\(violations.priority == 1 ? "" : "s")"
        }
        if violations.priorityFoundation > 0 {
            return "\(violations.priorityFoundation) priority-foundation violation\(violations.priorityFoundation == 1 ? "" : "s")"
        }
        if outcome == .followUpRequired { return "Follow-up inspection required" }
        if violations.core > 0 {
            return "\(violations.core) core violation\(violations.core == 1 ? "" : "s")"
        }
        return outcome.displayName
    }
}

enum RestaurantInspectionPortal {
    static let searchURL = URL(string: "https://dc.healthinspections.us/?a=Inspections")!
    static let guidanceURL = URL(string: "https://dchealth.dc.gov/service/understanding-food-establishment-inspections")!
    static let closuresURL = URL(string: "https://dchealth.dc.gov/node/1405521")!
}

struct RestaurantInspectionQuery: Equatable, Sendable {
    static let metersPerMile = 1_609.344

    let center: PulseItem.Coordinate
    let radiusMiles: Double
    let filter: RestaurantInspection.Filter

    func apply(to inspections: [RestaurantInspection]) -> [RestaurantInspection] {
        guard radiusMiles.isFinite, radiusMiles > 0 else { return [] }
        let origin = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude
        )
        let maximumDistance = radiusMiles * Self.metersPerMile
        return inspections
            .filter { inspection in
                guard inspection.isIncluded(in: filter) else { return false }
                let location = CLLocation(
                    latitude: inspection.coordinate.latitude,
                    longitude: inspection.coordinate.longitude
                )
                return origin.distance(from: location) <= maximumDistance
            }
            .sorted { $0.inspectionDate > $1.inspectionDate }
    }
}

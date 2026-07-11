import Foundation

enum SampleData {
    static let center = PulseItem.Coordinate(latitude: 38.9072, longitude: -77.0369)!

    static let items: [PulseItem] = [
        PulseItem(
            id: .init(source: .serviceRequests311, sourceIdentifier: "sample-311-001"),
            category: "Street & Alley", subtype: "Pothole", title: "Pothole repair requested",
            summary: "A street repair request is active near Logan Circle.", status: .active,
            openedAt: Date.now.addingTimeInterval(-2 * 86_400), updatedAt: Date.now.addingTimeInterval(-7_200), closedAt: nil,
            coordinate: .init(latitude: 38.9097, longitude: -77.0311), address: "1400 P Street NW", wardOrNeighborhood: "Ward 2",
            responsibleAgency: "District Department of Transportation",
            sourceAttributes: [.init(label: "Priority", value: "Standard")], sourceURL: nil
        ),
        PulseItem(
            id: .init(source: .buildingPermits2026, sourceIdentifier: "sample-building-001"),
            category: "Building", subtype: "Alteration", title: "Residential alteration permit",
            summary: "Interior renovation permit activity.", status: .new,
            openedAt: Date.now.addingTimeInterval(-5 * 86_400), updatedAt: nil, closedAt: nil,
            coordinate: .init(latitude: 38.9007, longitude: -77.0431), address: "900 21st Street NW", wardOrNeighborhood: "Ward 2",
            responsibleAgency: "Department of Buildings",
            sourceAttributes: [.init(label: "Permit type", value: "Alteration and Repair")], sourceURL: nil
        ),
        PulseItem(
            id: .init(source: .ddotConstructionPermits2026, sourceIdentifier: "sample-ddot-001"),
            category: "Transportation", subtype: "Public Space", title: "Sidewalk work completed",
            summary: "Recent public-space construction permit activity.", status: .resolved,
            openedAt: Date.now.addingTimeInterval(-20 * 86_400), updatedAt: Date.now.addingTimeInterval(-4 * 86_400), closedAt: Date.now.addingTimeInterval(-4 * 86_400),
            coordinate: .init(latitude: 38.9146, longitude: -77.0408), address: "1800 18th Street NW", wardOrNeighborhood: "Ward 2",
            responsibleAgency: "District Department of Transportation",
            sourceAttributes: [.init(label: "Work type", value: "Sidewalk")], sourceURL: nil
        )
    ]
}

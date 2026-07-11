import Foundation

struct ServiceRequest311Adapter: Sendable {
    static let sourceURL = URL(string: "https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/ServiceRequests/FeatureServer/21")!

    func map(_ feature: ArcGISFeature) throws -> PulseItem {
        let attributes = feature.attributes
        guard let identifier = attributes.string("SERVICEREQUESTID"), !identifier.isEmpty else {
            throw PulseItemMappingError.missingStableIdentifier
        }
        guard let openedAt = SourceDateParser.date(from: attributes["ADDDATE"]) else {
            throw PulseItemMappingError.missingRequiredField("ADDDATE")
        }
        let category = attributes.string("SERVICECODEDESCRIPTION") ?? "311 Service Request"
        let coordinate = coordinate(from: feature, attributes: attributes)
        let rawStatus = attributes.string("SERVICEORDERSTATUS") ?? attributes.string("STATUS_CODE")
        let priority = attributes.string("PRIORITY")

        return PulseItem(
            id: .init(source: .serviceRequests311, sourceIdentifier: identifier),
            category: category,
            subtype: attributes.string("SERVICETYPECODEDESCRIPTION"),
            title: category,
            summary: attributes.string("DETAILS"),
            status: status(from: rawStatus),
            openedAt: openedAt,
            updatedAt: SourceDateParser.date(from: attributes["EDITED"]),
            closedAt: SourceDateParser.date(from: attributes["RESOLUTIONDATE"]),
            coordinate: coordinate,
            address: attributes.string("STREETADDRESS"),
            wardOrNeighborhood: attributes.string("WARD"),
            responsibleAgency: attributes.string("ORGANIZATIONACRONYM"),
            sourceAttributes: [
                priority.map { .init(label: "Priority", value: $0) },
                rawStatus.map { .init(label: "Source status", value: $0) },
                attributes.string("SERVICETYPECODEDESCRIPTION").map { .init(label: "Service type", value: $0) }
            ].compactMap { $0 },
            sourceURL: Self.sourceURL
        )
    }

    private func coordinate(from feature: ArcGISFeature, attributes: [String: JSONValue]) -> PulseItem.Coordinate? {
        if let x = feature.geometry?.x, let y = feature.geometry?.y {
            return PulseItem.Coordinate(latitude: y, longitude: x)
        }
        guard let latitude = attributes.number("LATITUDE"), let longitude = attributes.number("LONGITUDE") else { return nil }
        return PulseItem.Coordinate(latitude: latitude, longitude: longitude)
    }

    private func status(from value: String?) -> PulseItem.Status {
        guard let value = value?.lowercased() else { return .unknown }
        if value.contains("close") || value.contains("complete") || value.contains("resolve") { return .resolved }
        if value.contains("open") || value.contains("in progress") || value.contains("assigned") { return .active }
        if value.contains("new") { return .new }
        return .unknown
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        guard case .string(let value) = self[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    func number(_ key: String) -> Double? {
        guard case .number(let value) = self[key] else { return nil }
        return value
    }
}

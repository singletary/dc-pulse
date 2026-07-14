import Foundation

struct ServiceRequest311Adapter: Sendable {
    static let sourceURL = URL(string: "https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/ServiceRequests/FeatureServer/21")!
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { .now }) {
        self.now = now
    }

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
            status: status(from: rawStatus, openedAt: openedAt),
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
            sourceURL: sourceURL(for: identifier)
        )
    }

    private func coordinate(from feature: ArcGISFeature, attributes: [String: JSONValue]) -> PulseItem.Coordinate? {
        if let x = feature.geometry?.x, let y = feature.geometry?.y {
            return PulseItem.Coordinate(latitude: y, longitude: x)
        }
        guard let latitude = attributes.number("LATITUDE"), let longitude = attributes.number("LONGITUDE") else { return nil }
        return PulseItem.Coordinate(latitude: latitude, longitude: longitude)
    }

    private func status(from value: String?, openedAt: Date) -> PulseItem.Status {
        guard let value = value?.lowercased().replacingOccurrences(of: "-", with: " ") else { return .unknown }
        if value.contains("close") || value.contains("complete") || value.contains("resolve") { return .resolved }
        let isUnresolved = value.contains("open") || value.contains("in progress") || value.contains("assigned") || value.contains("new")
        let age = now().timeIntervalSince(openedAt)
        if isUnresolved, age >= 0, age <= 48 * 60 * 60 { return .new }
        if isUnresolved { return .active }
        return .unknown
    }

    private func sourceURL(for identifier: String) -> URL? {
        guard var components = URLComponents(url: Self.sourceURL.appendingPathComponent("query"), resolvingAgainstBaseURL: false) else { return nil }
        let escapedIdentifier = identifier.replacingOccurrences(of: "'", with: "''")
        components.queryItems = [
            URLQueryItem(name: "where", value: "SERVICEREQUESTID='\(escapedIdentifier)'"),
            URLQueryItem(name: "outFields", value: "*"),
            URLQueryItem(name: "returnGeometry", value: "true"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "f", value: "pjson")
        ]
        return components.url
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

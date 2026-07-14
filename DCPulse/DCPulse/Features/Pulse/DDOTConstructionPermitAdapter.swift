import Foundation

struct DDOTConstructionPermitAdapter: Sendable {
    static let sourceURL = URL(string: "https://maps2.dcgis.dc.gov/dcgis/rest/services/FEEDS/DDOT/FeatureServer/48")!
    static let attributionURL = URL(string: "https://opendata.dc.gov/datasets/DCGIS::construction-permits-in-2026")!
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { .now }) {
        self.now = now
    }

    func map(_ feature: ArcGISFeature) throws -> PulseItem {
        let attributes = feature.attributes
        guard let identifier = attributes.text("PERMITNUMBER") ?? attributes.text("TRACKINGNUMBER") else {
            throw PulseItemMappingError.missingStableIdentifier
        }
        guard let appliedAt = SourceDateParser.date(from: attributes["APPLICATIONDATE"]) else {
            throw PulseItemMappingError.missingRequiredField("APPLICATIONDATE")
        }

        let rawStatus = attributes.text("STATUS")
        let workTypes = workTypes(from: attributes)
        let subtype = workTypes.isEmpty ? "Public Space Construction" : workTypes.joined(separator: " & ")

        return PulseItem(
            id: .init(source: .ddotConstructionPermits2026, sourceIdentifier: identifier),
            category: "DDOT Construction Permit",
            subtype: subtype,
            title: "\(subtype) permit",
            summary: attributes.text("WORKDETAIL"),
            status: status(from: rawStatus, appliedAt: appliedAt),
            openedAt: appliedAt,
            updatedAt: SourceDateParser.date(from: attributes["EDITED"]) ?? SourceDateParser.date(from: attributes["ISSUEDATE"]),
            closedAt: nil,
            coordinate: coordinate(from: feature, attributes: attributes),
            address: attributes.text("WLFULLADDRESS"),
            wardOrNeighborhood: nil,
            responsibleAgency: "District Department of Transportation",
            sourceAttributes: [
                attributes.text("TRACKINGNUMBER").map { .init(label: "Tracking number", value: $0) },
                attributes.text("PERMITNUMBER").map { .init(label: "Permit number", value: $0) },
                rawStatus.map { .init(label: "Application status", value: $0) },
                attributes.text("PERMITTEENAME").map { .init(label: "Permittee", value: $0) },
                dateAttribute("Issue date", attributes["ISSUEDATE"]),
                dateAttribute("Effective date", attributes["EFFECTIVEDATE"]),
                dateAttribute("Expiration date", attributes["EXPIRATIONDATE"]),
                workTypes.isEmpty ? nil : .init(label: "Work types", value: workTypes.joined(separator: ", "))
            ].compactMap { $0 },
            sourceURL: Self.attributionURL
        )
    }

    private func status(from value: String?, appliedAt: Date) -> PulseItem.Status {
        let status = value?.lowercased() ?? ""
        if status.contains("cancel") || status.contains("withdraw") || status.contains("deny") ||
            status.contains("expire") || status.contains("complete") || status.contains("close") {
            return .resolved
        }
        let age = now().timeIntervalSince(appliedAt)
        return age >= 0 && age <= 48 * 60 * 60 ? .new : .active
    }

    private func workTypes(from attributes: [String: JSONValue]) -> [String] {
        [
            ("ISEXCAVATION", "Excavation"), ("ISFIXTURE", "Fixture"), ("ISPAVING", "Paving"),
            ("ISLANDSCAPING", "Landscaping"), ("ISPROJECTIONS", "Projection"),
            ("ISPSRENTAL", "Public Space Rental")
        ].compactMap { attributes.isTrue($0.0) ? $0.1 : nil }
    }

    private func dateAttribute(_ label: String, _ value: JSONValue?) -> PulseItem.SourceAttribute? {
        guard let date = SourceDateParser.date(from: value) else { return nil }
        return .init(label: label, value: date.formatted(.dateTime.month().day().year()))
    }

    private func coordinate(from feature: ArcGISFeature, attributes: [String: JSONValue]) -> PulseItem.Coordinate? {
        if let x = feature.geometry?.x, let y = feature.geometry?.y,
           let coordinate = PulseItem.Coordinate(latitude: y, longitude: x), coordinate.isWithinDCServiceArea {
            return coordinate
        }
        guard let latitude = attributes.number("LATITUDE"), let longitude = attributes.number("LONGITUDE"),
              let coordinate = PulseItem.Coordinate(latitude: latitude, longitude: longitude), coordinate.isWithinDCServiceArea else {
            return nil
        }
        return coordinate
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func text(_ key: String) -> String? {
        guard case .string(let value) = self[key] else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func number(_ key: String) -> Double? {
        guard case .number(let value) = self[key] else { return nil }
        return value
    }

    func isTrue(_ key: String) -> Bool {
        text(key)?.uppercased() == "T"
    }
}

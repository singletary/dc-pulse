import Foundation

struct BuildingPermitAdapter: Sendable {
    static let sourceURL = URL(string: "https://maps2.dcgis.dc.gov/dcgis/rest/services/FEEDS/DCRA/FeatureServer/18")!
    static let attributionURL = URL(string: "https://opendata.dc.gov/datasets/DCGIS::building-permits-in-2026")!
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { .now }) {
        self.now = now
    }

    func map(_ feature: ArcGISFeature) throws -> PulseItem {
        let attributes = feature.attributes
        guard let identifier = attributes.text("PERMIT_ID") else {
            throw PulseItemMappingError.missingStableIdentifier
        }
        guard let issuedAt = SourceDateParser.date(from: attributes["ISSUE_DATE"]) else {
            throw PulseItemMappingError.missingRequiredField("ISSUE_DATE")
        }

        let permitType = attributes.text("PERMIT_TYPE_NAME") ?? "Building"
        let subtype = attributes.text("PERMIT_SUBTYPE_NAME")
        let rawStatus = attributes.text("APPLICATION_STATUS_NAME")
        let area = attributes.text("NEIGHBORHOODCLUSTER") ?? attributes.text("WARD").map { "Ward \($0)" }
        let permitCategory = attributes.text("PERMIT_CATEGORY_NAME").flatMap { value -> PulseItem.SourceAttribute? in
            value == "NA" ? nil : .init(label: "Permit category", value: value)
        }

        return PulseItem(
            id: .init(source: .buildingPermits2026, sourceIdentifier: identifier),
            category: "Building Permit",
            subtype: subtype ?? permitType,
            title: subtype.map { "\($0.capitalized) permit" } ?? "\(permitType.capitalized) permit",
            summary: attributes.text("DESC_OF_WORK"),
            status: status(from: rawStatus, issuedAt: issuedAt),
            openedAt: issuedAt,
            updatedAt: SourceDateParser.date(from: attributes["LASTMODIFIEDDATE"]),
            closedAt: nil,
            coordinate: coordinate(from: feature, attributes: attributes),
            address: attributes.text("FULL_ADDRESS"),
            wardOrNeighborhood: area,
            responsibleAgency: "Department of Buildings",
            sourceAttributes: [
                .init(label: "Permit type", value: permitType),
                subtype.map { .init(label: "Permit subtype", value: $0) },
                permitCategory,
                rawStatus.map { .init(label: "Application status", value: $0) },
                attributes.text("ZONING").map { .init(label: "Zoning", value: $0) },
                attributes.text("SSL").map { .init(label: "Square and lot", value: $0) },
                attributes.number("FEES_PAID").map { .init(label: "Fees paid", value: $0.formatted(.currency(code: "USD").precision(.fractionLength(0)))) }
            ].compactMap { $0 },
            sourceURL: Self.attributionURL
        )
    }

    private func status(from value: String?, issuedAt: Date) -> PulseItem.Status {
        let status = value?.lowercased() ?? ""
        if status.contains("cancel") || status.contains("withdraw") || status.contains("deny") || status.contains("expire") {
            return .resolved
        }
        let age = now().timeIntervalSince(issuedAt)
        return age >= 0 && age <= 48 * 60 * 60 ? .new : .active
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
}

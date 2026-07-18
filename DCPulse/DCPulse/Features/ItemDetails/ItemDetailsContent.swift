import Foundation

struct ItemDetailField: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let value: String
}

enum ItemDetailsContent {
    static func fields(for item: PulseItem) -> [ItemDetailField] {
        var fields = [
            field("source", "Source", item.id.source.displayName),
            field("category", "Category", item.category),
            field("status", "Status", item.status.displayName),
            field("identifier", identifierLabel(for: item), item.id.sourceIdentifier),
            field("opened", primaryDateLabel(for: item), dateString(item.openedAt))
        ]
        if let subtype = nonempty(item.subtype) { fields.append(field("subtype", "Type", subtype)) }
        if let updatedAt = item.updatedAt { fields.append(field("updated", "Updated", dateString(updatedAt))) }
        if let closedAt = item.closedAt { fields.append(field("completed", "Completed", dateString(closedAt))) }
        if let agency = nonempty(item.responsibleAgency) { fields.append(field("agency", "Agency", agency)) }
        fields += item.sourceAttributes.enumerated().compactMap { index, attribute in
            guard let value = nonempty(attribute.value) else { return nil }
            return field("attribute-\(index)-\(attribute.label)", attribute.label, value)
        }
        return fields
    }

    static func violationFields(for item: PulseItem) -> [ItemDetailField] {
        var fields = [field("violation-reference", "Reference", item.id.sourceIdentifier)]
        if let address = nonempty(item.address) { fields.append(field("violation-location", "Location", address)) }
        fields.append(field("violation-type", "Request type", nonempty(item.subtype) ?? item.category))
        if let summary = nonempty(item.summary) { fields.append(field("violation-description", "Work description", summary)) }
        return fields
    }

    static func summary(for fields: [ItemDetailField]) -> String {
        fields.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
    }

    private static func field(_ id: String, _ label: String, _ value: String) -> ItemDetailField {
        ItemDetailField(id: id, label: label, value: value)
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private static func dateString(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().year())
    }

    private static func identifierLabel(for item: PulseItem) -> String {
        switch item.id.source {
        case .serviceRequests311: "Request ID"
        case .buildingPermits2026: "Permit ID"
        case .ddotConstructionPermits2026: "Tracking or permit ID"
        }
    }

    private static func primaryDateLabel(for item: PulseItem) -> String {
        switch item.id.source {
        case .serviceRequests311: "Opened"
        case .buildingPermits2026: "Issued"
        case .ddotConstructionPermits2026: "Applied"
        }
    }
}

import Foundation
import Testing
@testable import DCPulse

@MainActor
struct ItemDetailsContentTests {
    @Test func generalDetailsAreCompleteAndExcludeCoordinates() throws {
        let item = makeItem()
        let fields = ItemDetailsContent.fields(for: item)
        let summary = ItemDetailsContent.summary(for: fields)

        #expect(fields.contains { $0.label == "Permit ID" && $0.value == "PERMIT-42" })
        #expect(fields.contains { $0.label == "Status" && $0.value == "Active" })
        #expect(fields.contains { $0.label == "Agency" && $0.value == "Department of Buildings" })
        #expect(fields.contains { $0.label == "Work type" && $0.value == "Renovation" })
        #expect(!summary.contains("38.9"))
        #expect(!summary.contains("-77.0"))
    }

    @Test func violationSummaryContainsOnlyUsefulVisibleHandoffFields() {
        let fields = ItemDetailsContent.violationFields(for: makeItem())
        let summary = ItemDetailsContent.summary(for: fields)

        #expect(fields.map(\.label) == ["Reference", "Location", "Request type", "Work description"])
        #expect(summary.contains("Reference: PERMIT-42"))
        #expect(summary.contains("Location: 100 Example Street NW"))
        #expect(summary.contains("Request type: Alteration"))
        #expect(summary.contains("Work description: Interior renovation"))
    }

    @Test func serviceRequestUsesRequestSpecificLabelsAndCuratedAttributes() {
        let item = makeCustomItem(
            source: .serviceRequests311,
            identifier: "26-00012345",
            attributes: [.init(label: "Service due", value: "July 31, 2026")]
        )
        let fields = ItemDetailsContent.fields(for: item)

        #expect(fields.contains { $0.label == "Request ID" && $0.value == "26-00012345" })
        #expect(fields.contains { $0.label == "Opened" })
        #expect(fields.contains { $0.label == "Service due" && $0.value == "July 31, 2026" })
        #expect(!fields.contains { $0.label == "Permit ID" })
    }

    @Test func ddotPermitUsesTrackingAndAppliedLabels() {
        let item = makeCustomItem(
            source: .ddotConstructionPermits2026,
            identifier: "DDOT-77"
        )
        let fields = ItemDetailsContent.fields(for: item)

        #expect(fields.contains { $0.label == "Tracking or permit ID" && $0.value == "DDOT-77" })
        #expect(fields.contains { $0.label == "Applied" })
        #expect(!fields.contains { $0.label == "Issued" || $0.label == "Opened" })
    }

    @Test func missingAndWhitespaceOnlyOptionalFieldsAreOmitted() {
        let item = makeCustomItem(
            subtype: "  ",
            agency: "\n",
            attributes: [
                .init(label: "Empty", value: "  "),
                .init(label: "Useful", value: "  Reviewed value  ")
            ]
        )
        let fields = ItemDetailsContent.fields(for: item)

        #expect(!fields.contains { $0.id == "subtype" || $0.id == "agency" })
        #expect(!fields.contains { $0.label == "Empty" })
        #expect(fields.contains { $0.label == "Useful" && $0.value == "Reviewed value" })
    }

    @Test func copiedSummaryHasStableFieldOrderAndExcludesHiddenContext() {
        let item = makeCustomItem(
            source: .serviceRequests311,
            identifier: "26-00012345",
            attributes: [.init(label: "Service type", value: "Pothole")]
        )
        let fields = ItemDetailsContent.fields(for: item)
        let summary = ItemDetailsContent.summary(for: fields)

        #expect(Array(fields.prefix(5).map(\.id)) == ["source", "category", "status", "identifier", "opened"])
        #expect(!summary.contains(item.address!))
        #expect(!summary.contains(item.summary!))
        #expect(!summary.contains(String(item.coordinate!.latitude)))
        #expect(!summary.contains(String(item.coordinate!.longitude)))
    }

    private func makeItem() -> PulseItem {
        makeCustomItem(
            source: .buildingPermits2026,
            identifier: "PERMIT-42",
            subtype: "Alteration",
            agency: "Department of Buildings",
            attributes: [.init(label: "Work type", value: "Renovation")]
        )
    }

    private func makeCustomItem(
        source: PulseItem.Source = .buildingPermits2026,
        identifier: String = "PERMIT-42",
        subtype: String? = "Alteration",
        agency: String? = "Department of Buildings",
        attributes: [PulseItem.SourceAttribute] = [.init(label: "Work type", value: "Renovation")]
    ) -> PulseItem {
        PulseItem(
            id: .init(source: source, sourceIdentifier: identifier),
            category: "Building Permit",
            subtype: subtype,
            title: "Alteration permit",
            summary: "Interior renovation",
            status: .active,
            openedAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: nil,
            closedAt: nil,
            coordinate: PulseItem.Coordinate(latitude: 38.9, longitude: -77.0),
            address: "100 Example Street NW",
            wardOrNeighborhood: "Ward 1",
            responsibleAgency: agency,
            sourceAttributes: attributes,
            sourceURL: nil
        )
    }
}

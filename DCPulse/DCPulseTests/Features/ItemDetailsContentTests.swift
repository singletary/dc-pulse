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

    private func makeItem() -> PulseItem {
        PulseItem(
            id: .init(source: .buildingPermits2026, sourceIdentifier: "PERMIT-42"),
            category: "Building Permit",
            subtype: "Alteration",
            title: "Alteration permit",
            summary: "Interior renovation",
            status: .active,
            openedAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: nil,
            closedAt: nil,
            coordinate: PulseItem.Coordinate(latitude: 38.9, longitude: -77.0),
            address: "100 Example Street NW",
            wardOrNeighborhood: "Ward 1",
            responsibleAgency: "Department of Buildings",
            sourceAttributes: [.init(label: "Work type", value: "Renovation")],
            sourceURL: nil
        )
    }
}

import Foundation
import Testing
@testable import DCPulse

@MainActor
struct RestaurantInspectionTests {
    @Test func closuresAndPriorityViolationsAreHighlighted() {
        let closed = inspection(outcome: .closed, priority: 0, foundation: 0, core: 0)
        let priority = inspection(outcome: .followUpRequired, priority: 1, foundation: 2, core: 3)
        let passed = inspection(outcome: .passed, priority: 0, foundation: 0, core: 0)

        #expect(closed.needsAttention)
        #expect(closed.attentionSummary.contains("Closed"))
        #expect(priority.needsAttention)
        #expect(priority.attentionSummary == "1 priority violation")
        #expect(!passed.needsAttention)
        #expect(passed.attentionSummary == "Passed")
    }

    @Test func officialPortalDestinationsRemainHTTPS() {
        #expect(RestaurantInspectionPortal.searchURL.scheme == "https")
        #expect(RestaurantInspectionPortal.searchURL.host == "dc.healthinspections.us")
        #expect(RestaurantInspectionPortal.guidanceURL.host == "dchealth.dc.gov")
        #expect(RestaurantInspectionPortal.closuresURL.host == "dchealth.dc.gov")
    }

    @Test func mapHighlightsOnlyTheMostSeriousInspectionsByDefault() {
        let closed = inspection(outcome: .closed, priority: 0, foundation: 0, core: 0)
        let priority = inspection(outcome: .followUpRequired, priority: 1, foundation: 0, core: 0)
        let foundation = inspection(outcome: .followUpRequired, priority: 0, foundation: 3, core: 2)
        let passed = inspection(outcome: .passed, priority: 0, foundation: 0, core: 0)

        #expect(closed.mapVisibility == .highlightedByDefault)
        #expect(priority.mapVisibility == .highlightedByDefault)
        #expect(foundation.mapVisibility == .availableThroughFilter)
        #expect(passed.mapVisibility == .availableThroughFilter)
    }

    private func inspection(
        outcome: RestaurantInspection.Outcome,
        priority: Int,
        foundation: Int,
        core: Int
    ) -> RestaurantInspection {
        RestaurantInspection(
            id: .init(permitIdentifier: "fixture-permit", inspectionIdentifier: "fixture-inspection"),
            establishmentName: "Example Restaurant",
            address: "REDACTED TEST ADDRESS",
            ward: "Ward 1",
            inspectionDate: Date(timeIntervalSince1970: 1_700_000_000),
            inspectionType: "Routine",
            outcome: outcome,
            violations: .init(priority: priority, priorityFoundation: foundation, core: core),
            reportURL: RestaurantInspectionPortal.searchURL
        )
    }
}

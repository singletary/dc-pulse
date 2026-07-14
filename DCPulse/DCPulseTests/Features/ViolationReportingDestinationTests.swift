import Foundation
import Testing
@testable import DCPulse

@MainActor
struct ViolationReportingDestinationTests {
    @Test func routesBuildingPermitsToOfficialDOBInspectionForm() throws {
        let item = permit(source: .buildingPermits2026)
        let destination = try #require(ViolationReportingDestination(item: item))

        #expect(destination.url.host == "inspections.dob.dc.gov")
        #expect(destination.url.path == "/forms/illegal_construction_inspection/step_1")
    }

    @Test func routesDDOTPermitsToOfficial311EntryAndExcludes311Requests() throws {
        let ddot = try #require(ViolationReportingDestination(item: permit(source: .ddotConstructionPermits2026)))
        #expect(ddot.url.host == "311.dc.gov")
        #expect(ViolationReportingDestination(item: permit(source: .serviceRequests311)) == nil)
    }

    private func permit(source: PulseItem.Source) -> PulseItem {
        PulseItem(
            id: .init(source: source, sourceIdentifier: "permit-123"),
            category: "Construction",
            subtype: nil,
            title: "Construction permit",
            summary: nil,
            status: .active,
            openedAt: .now,
            updatedAt: nil,
            closedAt: nil,
            coordinate: nil,
            address: nil,
            wardOrNeighborhood: nil,
            responsibleAgency: nil,
            sourceAttributes: [],
            sourceURL: nil
        )
    }
}

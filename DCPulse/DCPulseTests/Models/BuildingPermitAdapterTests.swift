import Foundation
import Testing
@testable import DCPulse

@MainActor
struct BuildingPermitAdapterTests {
    @Test func mapsVerifiedBuildingPermitSchema() throws {
        let page = try JSONDecoder().decode(ArcGISFeaturePage.self, from: TestFixture.data(named: "building-permit-2026"))
        let feature = try #require(page.features.first)
        let issuedAt = try #require(SourceDateParser.date(from: feature.attributes["ISSUE_DATE"]))
        let item = try BuildingPermitAdapter(now: { issuedAt.addingTimeInterval(24 * 60 * 60) }).map(feature)

        #expect(item.id == .init(source: .buildingPermits2026, sourceIdentifier: "fixture-permit-001"))
        #expect(item.category == "Building Permit")
        #expect(item.subtype == "ELEVATOR - ALTERATION")
        #expect(item.status == .new)
        #expect(item.coordinate == .init(latitude: 38.9010, longitude: -77.0310))
        #expect(item.address == "REDACTED TEST ADDRESS")
        #expect(item.responsibleAgency == "Department of Buildings")
        #expect(item.sourceAttributes.contains { $0.label == "Fees paid" && $0.value.contains("22,000") })
    }

    @Test func rejectsPermitWithoutIdentifierOrIssueDate() {
        let missingIdentifier = ArcGISFeature(attributes: ["ISSUE_DATE": .number(1_783_483_200_000)], geometry: nil)
        #expect(throws: PulseItemMappingError.missingStableIdentifier) { try BuildingPermitAdapter().map(missingIdentifier) }

        let missingDate = ArcGISFeature(attributes: ["PERMIT_ID": .string("P-1")], geometry: nil)
        #expect(throws: PulseItemMappingError.missingRequiredField("ISSUE_DATE")) { try BuildingPermitAdapter().map(missingDate) }
    }

    @Test func dropsInvalidOrOutOfAreaCoordinatesWithoutDroppingPermit() throws {
        let feature = ArcGISFeature(attributes: [
            "PERMIT_ID": .string("P-2"),
            "ISSUE_DATE": .number(1_783_483_200_000),
            "LATITUDE": .number(0),
            "LONGITUDE": .number(0)
        ], geometry: .init(x: 0, y: 0))

        let item = try BuildingPermitAdapter().map(feature)
        #expect(item.coordinate == nil)
    }
}

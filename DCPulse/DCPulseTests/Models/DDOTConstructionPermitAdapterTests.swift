import Foundation
import Testing
@testable import DCPulse

@MainActor
struct DDOTConstructionPermitAdapterTests {
    @Test func mapsVerifiedDDOTSchema() throws {
        let page = try JSONDecoder().decode(ArcGISFeaturePage.self, from: TestFixture.data(named: "ddot-construction-permit-2026"))
        let feature = try #require(page.features.first)
        let appliedAt = try #require(SourceDateParser.date(from: feature.attributes["APPLICATIONDATE"]))
        let item = try DDOTConstructionPermitAdapter(now: { appliedAt.addingTimeInterval(24 * 60 * 60) }).map(feature)

        #expect(item.id == .init(source: .ddotConstructionPermits2026, sourceIdentifier: "fixture-ddot-001"))
        #expect(item.category == "DDOT Construction Permit")
        #expect(item.subtype == "Excavation")
        #expect(item.title == "Excavation permit")
        #expect(item.status == .new)
        #expect(item.coordinate == .init(latitude: 38.9020, longitude: -77.0320))
        #expect(item.responsibleAgency == "District Department of Transportation")
        #expect(item.sourceAttributes.contains { $0.label == "Effective date" })
        #expect(item.sourceURL == DDOTConstructionPermitAdapter.attributionURL)
    }

    @Test func prefersPermitNumberAndClassifiesClosedStatuses() throws {
        let appliedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let feature = ArcGISFeature(attributes: [
            "TRACKINGNUMBER": .string("tracking"),
            "PERMITNUMBER": .string("permit"),
            "APPLICATIONDATE": .number(appliedAt.timeIntervalSince1970 * 1_000),
            "STATUS": .string("Cancelled")
        ], geometry: nil)

        let item = try DDOTConstructionPermitAdapter(now: { appliedAt.addingTimeInterval(60 * 60) }).map(feature)
        #expect(item.id.sourceIdentifier == "permit")
        #expect(item.status == .resolved)
    }

    @Test func rejectsMissingIdentityOrApplicationDateAndToleratesInvalidCoordinates() throws {
        let missingIdentity = ArcGISFeature(attributes: ["APPLICATIONDATE": .number(1_780_000_000_000)], geometry: nil)
        #expect(throws: PulseItemMappingError.missingStableIdentifier) { try DDOTConstructionPermitAdapter().map(missingIdentity) }

        let missingDate = ArcGISFeature(attributes: ["TRACKINGNUMBER": .string("T-1")], geometry: nil)
        #expect(throws: PulseItemMappingError.missingRequiredField("APPLICATIONDATE")) { try DDOTConstructionPermitAdapter().map(missingDate) }

        let invalidCoordinate = ArcGISFeature(attributes: [
            "TRACKINGNUMBER": .string("T-2"), "APPLICATIONDATE": .number(1_780_000_000_000),
            "LATITUDE": .number(0), "LONGITUDE": .number(0)
        ], geometry: .init(x: 0, y: 0))
        #expect(try DDOTConstructionPermitAdapter().map(invalidCoordinate).coordinate == nil)
    }
}

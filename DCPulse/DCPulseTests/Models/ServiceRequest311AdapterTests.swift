import Foundation
import Testing
@testable import DCPulse

struct ServiceRequest311AdapterTests {
    @Test func mapsVerifiedServiceSchemaToPulseItem() throws {
        let page = try JSONDecoder().decode(ArcGISFeaturePage.self, from: TestFixture.data(named: "311-service-request"))
        let item = try ServiceRequest311Adapter().map(#require(page.features.first))
        #expect(item.id == .init(source: .serviceRequests311, sourceIdentifier: "fixture-311-001"))
        #expect(item.category == "Illegal Dumping")
        #expect(item.status == .active)
        #expect(item.coordinate == .init(latitude: 38.9111, longitude: -77.0204))
        #expect(item.responsibleAgency == "DPW")
        #expect(item.sourceURL == ServiceRequest311Adapter.sourceURL)
    }

    @Test func rejectsRecordWithoutStableIdentifier() throws {
        let feature = ArcGISFeature(attributes: ["ADDDATE": .number(1_700_000_000_000)], geometry: nil)
        #expect(throws: PulseItemMappingError.missingStableIdentifier) { try ServiceRequest311Adapter().map(feature) }
    }

    @Test func retainsListItemWhenCoordinateIsMissing() throws {
        let feature = ArcGISFeature(attributes: [
            "SERVICEREQUESTID": .string("no-map-point"),
            "ADDDATE": .number(1_700_000_000_000),
            "SERVICEORDERSTATUS": .string("Closed")
        ], geometry: nil)
        let item = try ServiceRequest311Adapter().map(feature)
        #expect(item.coordinate == nil)
        #expect(item.status == .resolved)
    }
}

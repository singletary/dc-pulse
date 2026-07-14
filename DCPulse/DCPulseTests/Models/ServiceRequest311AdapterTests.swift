import Foundation
import Testing
@testable import DCPulse

@MainActor
struct ServiceRequest311AdapterTests {
    @Test func mapsVerifiedServiceSchemaToPulseItem() throws {
        let page = try JSONDecoder().decode(ArcGISFeaturePage.self, from: TestFixture.data(named: "311-service-request"))
        let feature = try #require(page.features.first)
        let openedAt = try #require(SourceDateParser.date(from: feature.attributes["ADDDATE"]))
        let item = try ServiceRequest311Adapter(now: { openedAt.addingTimeInterval(24 * 60 * 60) }).map(feature)
        #expect(item.id == .init(source: .serviceRequests311, sourceIdentifier: "fixture-311-001"))
        #expect(item.category == "Illegal Dumping")
        #expect(item.status == .new)
        #expect(item.coordinate == .init(latitude: 38.9000, longitude: -77.0300))
        #expect(item.responsibleAgency == "DPW")
        #expect(item.sourceURL?.absoluteString.contains("fixture-311-001") == true)
    }


    @Test func classifiesOlderUnresolvedRequestAsActive() throws {
        let openedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let feature = ArcGISFeature(attributes: [
            "SERVICEREQUESTID": .string("older-open"),
            "ADDDATE": .number(openedAt.timeIntervalSince1970 * 1_000),
            "SERVICEORDERSTATUS": .string("Open")
        ], geometry: nil)

        let item = try ServiceRequest311Adapter(now: { openedAt.addingTimeInterval(49 * 60 * 60) }).map(feature)
        #expect(item.status == .active)
    }

    @Test func classifiesHyphenatedInProgressStatusAsActive() throws {
        let openedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let feature = ArcGISFeature(attributes: [
            "SERVICEREQUESTID": .string("in-progress"),
            "ADDDATE": .number(openedAt.timeIntervalSince1970 * 1_000),
            "SERVICEORDERSTATUS": .string("In-Progress")
        ], geometry: nil)

        let item = try ServiceRequest311Adapter(now: { openedAt.addingTimeInterval(72 * 60 * 60) }).map(feature)
        #expect(item.status == .active)
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

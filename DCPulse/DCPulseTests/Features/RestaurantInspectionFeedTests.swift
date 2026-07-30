import Foundation
import Testing
@testable import DCPulse

@MainActor
struct RestaurantInspectionFeedTests {
    private let generatedAt = ISO8601DateFormatter().date(from: "2026-07-29T16:00:00Z")!
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-07-29T17:00:00Z")!

    @Test func validVersionedFixtureMapsRequiredDisplayAndProvenanceFields() throws {
        let inspections = try adapter().map(fixture(), now: referenceDate)
        let first = try #require(inspections.first)

        #expect(inspections.count == 2)
        #expect(first.establishmentName == "Redacted Fixture Restaurant")
        #expect(first.coordinate.isWithinDCServiceArea)
        #expect(first.inspectionDate < generatedAt)
        #expect(first.outcome == .followUpRequired)
        #expect(first.violations.priorityFoundation == 2)
        #expect(first.feedGeneratedAt == generatedAt)
        #expect(first.attribution == "DC Health")
        #expect(first.sourceURL.host == "dchealth.dc.gov")
        #expect(first.reportURL.host == "dc.healthinspections.us")
    }

    @Test func killSwitchFailsBeforeDecodingOrPublishingRecords() {
        let disabled = RestaurantInspectionFeedAdapter(
            policy: .init(isEnabled: false, maximumAge: 86_400)
        )

        #expect(throws: RestaurantInspectionFeedError.disabled) {
            try disabled.map(Data("not json".utf8), now: referenceDate)
        }
    }

    @Test func unsupportedPayloadVersionFailsClosed() {
        let data = replacing(#""version": 1"#, with: #""version": 2"#)

        #expect(throws: RestaurantInspectionFeedError.unsupportedVersion(2)) {
            try adapter().map(data, now: referenceDate)
        }
    }

    @Test func changedSchemaFingerprintFailsClosed() {
        let data = replacing(
            RestaurantInspectionFeed.expectedSchema,
            with: "publisher.changed.v2"
        )

        #expect(throws: RestaurantInspectionFeedError.unexpectedSchema("publisher.changed.v2")) {
            try adapter().map(data, now: referenceDate)
        }
    }

    @Test func staleAndFutureFeedsAreRejected() {
        #expect(throws: RestaurantInspectionFeedError.staleFeed) {
            try adapter(maximumAge: 30 * 60).map(fixture(), now: referenceDate)
        }
        #expect(throws: RestaurantInspectionFeedError.futureFeed) {
            try adapter().map(
                fixture(),
                now: generatedAt.addingTimeInterval(-1)
            )
        }
    }

    @Test func invalidFreshnessPolicyFailsClosed() {
        let zero = RestaurantInspectionFeedAdapter(
            policy: .init(isEnabled: true, maximumAge: 0)
        )
        let infinite = RestaurantInspectionFeedAdapter(
            policy: .init(isEnabled: true, maximumAge: .infinity)
        )

        #expect(throws: RestaurantInspectionFeedError.invalidPolicy) {
            try zero.map(fixture(), now: referenceDate)
        }
        #expect(throws: RestaurantInspectionFeedError.invalidPolicy) {
            try infinite.map(fixture(), now: referenceDate)
        }
    }

    @Test func changedCoordinatesCountsOrInspectionDateRejectTheAffectedFeed() {
        let outsideDC = replacing(#""latitude": 38.9072"#, with: #""latitude": 40.0"#)
        #expect(throws: RestaurantInspectionFeedError.invalidRecord(index: 0)) {
            try adapter().map(outsideDC, now: referenceDate)
        }

        let negativeCount = replacing(
            #""priorityViolations": 0"#,
            with: #""priorityViolations": -1"#
        )
        #expect(throws: RestaurantInspectionFeedError.invalidRecord(index: 0)) {
            try adapter().map(negativeCount, now: referenceDate)
        }

        let futureInspection = replacing(
            "2026-07-28T14:00:00Z",
            with: "2026-07-30T14:00:00Z"
        )
        #expect(throws: RestaurantInspectionFeedError.invalidRecord(index: 0)) {
            try adapter().map(futureInspection, now: referenceDate)
        }
    }

    @Test func attributionAndSourceMustRemainExplicitAndSecure() {
        let emptyAttribution = replacing(#""attribution": "DC Health""#, with: #""attribution": " ""#)
        #expect(throws: RestaurantInspectionFeedError.invalidAttribution) {
            try adapter().map(emptyAttribution, now: referenceDate)
        }

        let insecureSource = replacing(
            "https://dchealth.dc.gov/service/division-food",
            with: "http://dchealth.dc.gov/service/division-food"
        )
        #expect(throws: RestaurantInspectionFeedError.invalidSourceURL) {
            try adapter().map(insecureSource, now: referenceDate)
        }
    }

    @Test func malformedPayloadDoesNotBecomeAnEmptySuccessfulFeed() {
        #expect(throws: RestaurantInspectionFeedError.decoding) {
            try adapter().map(Data(#"{"version":1}"#.utf8), now: referenceDate)
        }
    }

    @Test func activeSearchCenterRadiusAndFilterBoundFutureMapResults() throws {
        let inspections = try adapter().map(fixture(), now: referenceDate)
        let center = try #require(PulseItem.Coordinate(latitude: 38.9072, longitude: -77.0369))

        let attention = RestaurantInspectionQuery(
            center: center,
            radiusMiles: 0.25,
            filter: .needsAttention
        ).apply(to: inspections)
        let all = RestaurantInspectionQuery(
            center: center,
            radiusMiles: 5,
            filter: .all
        ).apply(to: inspections)

        #expect(attention.map(\.id.inspectionIdentifier) == ["fixture-inspection-1"])
        #expect(all.count == 2)
        #expect(all[0].inspectionDate > all[1].inspectionDate)
    }

    @Test func invalidSearchRadiusPublishesNoResults() throws {
        let inspections = try adapter().map(fixture(), now: referenceDate)
        let center = try #require(PulseItem.Coordinate(latitude: 38.9072, longitude: -77.0369))

        #expect(RestaurantInspectionQuery(
            center: center,
            radiusMiles: 0,
            filter: .all
        ).apply(to: inspections).isEmpty)
        #expect(RestaurantInspectionQuery(
            center: center,
            radiusMiles: .infinity,
            filter: .all
        ).apply(to: inspections).isEmpty)
    }

    private func adapter(maximumAge: TimeInterval = 2 * 24 * 60 * 60) -> RestaurantInspectionFeedAdapter {
        RestaurantInspectionFeedAdapter(
            policy: .init(isEnabled: true, maximumAge: maximumAge)
        )
    }

    private func fixture() throws -> Data {
        try TestFixture.data(named: "restaurant-inspections-v1")
    }

    private func replacing(_ target: String, with replacement: String) -> Data {
        let text = String(decoding: try! fixture(), as: UTF8.self)
        return Data(text.replacingOccurrences(of: target, with: replacement).utf8)
    }
}

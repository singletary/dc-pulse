import Foundation
import Testing
@testable import DCPulse

@MainActor
struct PulseItemTests {
    @Test func identityIsNamespacedByDataset() {
        let left = PulseItem.ID(source: .serviceRequests311, sourceIdentifier: "42")
        let right = PulseItem.ID(source: .buildingPermits2026, sourceIdentifier: "42")
        #expect(left != right)
    }

    @Test func coordinateRejectsNormalizationBoundaries() {
        #expect(PulseItem.Coordinate(latitude: 90, longitude: 180) != nil)
        #expect(PulseItem.Coordinate(latitude: 90.1, longitude: 0) == nil)
        #expect(PulseItem.Coordinate(latitude: 0, longitude: -180.1) == nil)
    }

    @Test func identifiesCoordinatesWithinDCServiceArea() throws {
        let dc = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))
        let positiveLongitude = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: 77.0300))

        #expect(dc.isWithinDCServiceArea)
        #expect(!positiveLongitude.isWithinDCServiceArea)
    }

    @Test func sourceDateParserSupportsEpochMillisecondsAndISO8601() {
        #expect(SourceDateParser.date(from: .number(1_700_000_000_000)) == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(SourceDateParser.date(from: .string("2026-07-05T12:00:00Z")) != nil)
        #expect(SourceDateParser.date(from: .string("not-a-date")) == nil)
        #expect(SourceDateParser.date(from: nil) == nil)
    }
}

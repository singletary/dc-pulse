import Foundation
import Testing
@testable import DCPulse

@MainActor
struct RequestTrendAnalyzerTests {
    @Test func comparesCompleteCategoryCountsAndCalculatesIncrease() throws {
        let snapshot = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Rodent Inspection": 6, "Graffiti Removal": 4],
            previousCounts: ["Rodent Inspection": 3]
        )

        let rodent = try #require(snapshot.trends.first { $0.category == "Rodent Inspection" })
        #expect(rodent.direction == .increased)
        #expect(rodent.currentCount == 6)
        #expect(rodent.previousCount == 3)
        #expect(rodent.percentChange == 100)

        let graffiti = try #require(snapshot.trends.first { $0.category == "Graffiti Removal" })
        #expect(graffiti.direction == .newlyObserved)
        #expect(snapshot.categories == ["Graffiti Removal", "Rodent Inspection"])
        #expect(snapshot.categoryCounts == ["Graffiti Removal": 4, "Rodent Inspection": 9])
    }

    @Test func suppressesUnchangedAndSmallSamplesButRetainsCategoryCatalog() {
        let snapshot = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Steady": 3, "Small": 1],
            previousCounts: ["Steady": 3, "Small": 1]
        )

        #expect(snapshot.trends.isEmpty)
        #expect(snapshot.categories == ["Small", "Steady"])
        #expect(snapshot.categoryCounts == ["Small": 2, "Steady": 6])
    }

    @Test func ranksLargestAbsoluteChangeFirst() throws {
        let snapshot = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Bulk": 20, "Trees": 2],
            previousCounts: ["Bulk": 10, "Trees": 8]
        )

        #expect(snapshot.trends.map(\.category) == ["Bulk", "Trees"])
        #expect(snapshot.trends[1].direction == .decreased)
    }

    @Test func provenanceSurvivesCacheEncoding() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.90, longitude: -77.03))
        let refreshedAt = Date(timeIntervalSince1970: 1_783_980_000)
        var snapshot = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Bulk": 8],
            previousCounts: ["Bulk": 4]
        )
        snapshot.provenance = .init(
            source: .serviceRequests311,
            coordinate: coordinate,
            radiusMiles: 0.5,
            selectedDays: 30,
            currentPeriod: DateInterval(start: refreshedAt.addingTimeInterval(-1_296_000), end: refreshedAt),
            previousPeriod: DateInterval(start: refreshedAt.addingTimeInterval(-2_592_000), end: refreshedAt.addingTimeInterval(-1_296_000)),
            refreshedAt: refreshedAt
        )

        let restored = try JSONDecoder().decode(
            RequestTrendSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )

        #expect(restored == snapshot)
    }

    @Test func decodesLegacyCachedSnapshotWithoutProvenance() throws {
        let data = Data(#"{"trends":[],"categories":["Bulk"],"categoryCounts":{"Bulk":4}}"#.utf8)
        let restored = try JSONDecoder().decode(RequestTrendSnapshot.self, from: data)

        #expect(restored.categories == ["Bulk"])
        #expect(restored.provenance == nil)
    }
}

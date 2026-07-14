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
    }

    @Test func suppressesUnchangedAndSmallSamplesButRetainsCategoryCatalog() {
        let snapshot = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Steady": 3, "Small": 1],
            previousCounts: ["Steady": 3, "Small": 1]
        )

        #expect(snapshot.trends.isEmpty)
        #expect(snapshot.categories == ["Small", "Steady"])
    }

    @Test func ranksLargestAbsoluteChangeFirst() throws {
        let snapshot = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Bulk": 20, "Trees": 2],
            previousCounts: ["Bulk": 10, "Trees": 8]
        )

        #expect(snapshot.trends.map(\.category) == ["Bulk", "Trees"])
        #expect(snapshot.trends[1].direction == .decreased)
    }
}

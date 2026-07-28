import Testing
@testable import DCPulse

@MainActor
struct NeighborhoodInsightPresentationTests {
    @Test func strongestTrendTakesPriorityOverLeadingCategory() throws {
        let trends = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Pothole": 14],
            previousCounts: ["Pothole": 11]
        ).trends

        let insight = try #require(NeighborhoodInsightPresentation(
            trends: trends,
            categoryCounts: ["Trash Collection": 40],
            windowDays: 15
        ))

        #expect(insight.category == "Pothole")
        #expect(insight.title == "Pothole increased nearby")
        #expect(insight.detail == "14 in the latest 15 days · up 27%")
        #expect(insight.style == .increased)
    }

    @Test func leadingCategoryIsTheFallbackWhenNoTrendQualifies() throws {
        let insight = try #require(NeighborhoodInsightPresentation(
            trends: [],
            categoryCounts: [
                "Tree Inspection": 4,
                "Illegal Dumping": 8,
                "Graffiti Removal": 8
            ],
            windowDays: 15
        ))

        #expect(insight.category == "Graffiti Removal")
        #expect(insight.title == "Graffiti Removal leads nearby requests")
        #expect(insight.detail == "8 in the selected period")
        #expect(insight.style == .leadingCategory)
    }

    @Test func unavailableCompleteInsightsDoNotCreateAPlaceholderClaim() {
        #expect(NeighborhoodInsightPresentation(
            trends: [],
            categoryCounts: [:],
            windowDays: 15
        ) == nil)
    }
}

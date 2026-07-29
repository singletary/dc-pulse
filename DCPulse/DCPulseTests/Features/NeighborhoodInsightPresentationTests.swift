import Testing
@testable import DCPulse

@MainActor
struct NeighborhoodInsightPresentationTests {
    @Test func strongestTrendTakesPriorityOverLeadingCategory() throws {
        let trends = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Pothole": 14],
            previousCounts: ["Pothole": 11]
        ).trends

        let insights = NeighborhoodInsightPresentation.insights(
            trends: trends,
            categoryCounts: ["Trash Collection": 40],
            windowDays: 15,
            status: nil
        )
        let insight = try #require(insights.first)

        #expect(insight.category == "Pothole")
        #expect(insight.title == "Pothole increased nearby")
        #expect(insight.detail == "14 in the latest 15 days · ↑ 27%")
        #expect(insight.style == .increased)
        #expect(insights.map(\.category) == ["Pothole", "Trash Collection"])
    }

    @Test func presentsUpToFourLeadingCategoriesWhenNoTrendQualifies() {
        let insights = NeighborhoodInsightPresentation.insights(
            trends: [],
            categoryCounts: [
                "Tree Inspection": 4,
                "Illegal Dumping": 8,
                "Graffiti Removal": 8,
                "Pothole": 6,
                "Streetlight Repair": 2
            ],
            windowDays: 15,
            status: nil
        )

        #expect(insights.map(\.category) == [
            "Graffiti Removal", "Illegal Dumping", "Pothole", "Tree Inspection"
        ])
        #expect(insights.first?.title == "Graffiti Removal")
        #expect(insights.first?.detail == "8 requests in the selected period")
        #expect(insights.allSatisfy { $0.style == .leadingCategory })
    }

    @Test func selectedStatusUsesOnlyMatchingCategoryCounts() {
        let trends = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Pothole": 14],
            previousCounts: ["Pothole": 11]
        ).trends
        let insights = NeighborhoodInsightPresentation.insights(
            trends: trends,
            categoryCounts: ["Trash Collection": 7, "Tree Inspection": 3],
            windowDays: 15,
            status: .active
        )

        #expect(insights.map(\.category) == ["Trash Collection", "Tree Inspection"])
        #expect(insights.first?.detail == "7 active requests in the selected period")
        #expect(!insights.contains { $0.category == "Pothole" })
    }

    @Test func decreasedTrendUsesArrowInsteadOfDirectionCopy() throws {
        let trends = RequestTrendAnalyzer.snapshot(
            currentCounts: ["Illegal Dumping": 2],
            previousCounts: ["Illegal Dumping": 10]
        ).trends
        let insight = try #require(NeighborhoodInsightPresentation.insights(
            trends: trends,
            categoryCounts: [:],
            windowDays: 15,
            status: nil
        ).first)

        #expect(insight.detail == "2 in the latest 15 days · ↓ 80%")
        #expect(!insight.detail.contains("down"))
    }

    @Test func unavailableCompleteInsightsDoNotCreateAPlaceholderClaim() {
        #expect(NeighborhoodInsightPresentation.insights(
            trends: [],
            categoryCounts: [:],
            windowDays: 15,
            status: nil
        ).isEmpty)
    }
}

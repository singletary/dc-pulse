import Testing
@testable import DCPulse

struct RequestCategorySummaryPresentationTests {
    @Test func collapsedSummaryShowsTheTopThreeCategoriesInStableOrder() {
        let summary = RequestCategorySummaryPresentation(counts: [
            "Tree Inspection": 4,
            "Graffiti Removal": 8,
            "Illegal Dumping": 8,
            "Streetlight Repair": 2
        ])

        #expect(summary.visibleCategories(showingAll: false) == [
            .init(name: "Graffiti Removal", count: 8),
            .init(name: "Illegal Dumping", count: 8),
            .init(name: "Tree Inspection", count: 4)
        ])
        #expect(summary.hasMoreCategories)
        #expect(summary.accessibilityValue(showingAll: false) == "Showing 3 of 4 categories")
    }

    @Test func expandedSummaryRevealsEveryCategoryWithoutReordering() {
        let summary = RequestCategorySummaryPresentation(counts: [
            "Streetlight Repair": 2,
            "Illegal Dumping": 8,
            "Tree Inspection": 4,
            "Graffiti Removal": 8
        ])

        #expect(summary.visibleCategories(showingAll: true) == summary.categories)
        #expect(summary.visibleCategories(showingAll: true).map(\.name) == [
            "Graffiti Removal", "Illegal Dumping", "Tree Inspection", "Streetlight Repair"
        ])
        #expect(summary.accessibilityValue(showingAll: true) == "Showing 4 of 4 categories")
    }

    @Test func shortSummaryDoesNotOfferExpansion() {
        let summary = RequestCategorySummaryPresentation(counts: [
            "Illegal Dumping": 2,
            "Tree Inspection": 1
        ])

        #expect(!summary.hasMoreCategories)
        #expect(summary.visibleCategories(showingAll: false) == summary.categories)
    }
}

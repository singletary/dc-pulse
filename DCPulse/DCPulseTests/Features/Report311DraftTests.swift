import Foundation
import Testing
@testable import DCPulse

@MainActor
struct Report311DraftTests {
    @Test func suggestsCivicCategoriesFromImageClassifications() {
        #expect(ReportSuggestionEngine.category(for: ["street", "pothole", "asphalt"]) == .pothole)
        #expect(ReportSuggestionEngine.category(for: ["Norway rat", "animal"]) == .rodentControl)
        #expect(ReportSuggestionEngine.category(for: ["spray paint", "wall"]) == .graffitiRemoval)
        #expect(ReportSuggestionEngine.category(for: ["unrelated object"]) == .other)
    }

    @Test func officialPortalSummaryContainsOnlyReviewedDraftFields() {
        var draft = Report311Draft()
        draft.category = .illegalDumping
        draft.details = "  Discarded furniture beside the alley.  "
        draft.address = "  9999 Example Avenue NW  "

        #expect(draft.summaryForOfficialPortal == """
        Suggested DC 311 category: Illegal dumping
        Details: Discarded furniture beside the alley.
        Location: 9999 Example Avenue NW
        """)
    }
}

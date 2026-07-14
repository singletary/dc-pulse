import Testing
@testable import DCPulse

@MainActor
struct ArcGISWhereClauseTests {
    @Test func quotesAndEscapesIdentifiers() {
        #expect(ArcGISWhereClause.quotedList(["123", "O'Brien"]) == "'123','O''Brien'")
    }
}

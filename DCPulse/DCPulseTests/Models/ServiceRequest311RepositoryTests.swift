import Foundation
import Testing
@testable import DCPulse

@MainActor
struct ServiceRequest311RepositoryTests {
    @Test func categoryQueryEscapesNameAndReturnsTargetedRecords() async throws {
        let page = try JSONDecoder().decode(
            ArcGISFeaturePage.self,
            from: Data(#"{"features":[{"attributes":{"SERVICEREQUESTID":"graffiti-1","ADDDATE":1783900000000,"SERVICEORDERSTATUS":"Open","SERVICECODEDESCRIPTION":"Graffiti Removal"},"geometry":{"x":-77.0300,"y":38.9000}}]}"#.utf8)
        )
        let client = CategoryPageClient(page: page)
        let repository = ServiceRequest311Repository(client: client, now: { Date(timeIntervalSince1970: 1_783_980_000) })
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))

        let items = try await repository.items(
            in: "Owner's Graffiti",
            coordinate: coordinate,
            radiusMiles: 0.5,
            days: 30,
            limit: 250
        )

        #expect(items.map(\.id.sourceIdentifier) == ["graffiti-1"])
        let query = try #require(await client.queries.first)
        #expect(query.whereClause.contains("SERVICECODEDESCRIPTION IN ('Owner''s Graffiti')"))
        #expect(query.resultRecordCount == 250)
        #expect(query.orderByFields == ["ADDDATE DESC"])
    }
}

private actor CategoryPageClient: ArcGISClientProtocol {
    let page: ArcGISFeaturePage
    private(set) var queries: [ArcGISQuery] = []

    init(page: ArcGISFeaturePage) { self.page = page }

    func fetchPage(from layerURL: URL, query: ArcGISQuery) async throws -> ArcGISFeaturePage {
        queries.append(query)
        return page
    }
}

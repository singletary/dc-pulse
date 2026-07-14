import Foundation
import Testing
@testable import DCPulse

@MainActor
struct ServiceRequest311TrendRepositoryTests {
    @Test func buildsCompleteTrendSnapshotFromGroupedCounts() async throws {
        let current = try page(#"{"features":[{"attributes":{"SERVICECODEDESCRIPTION":"Graffiti Removal","REQUEST_COUNT":4}},{"attributes":{"SERVICECODEDESCRIPTION":"Bulk Collection","REQUEST_COUNT":12}}]}"#)
        let previous = try page(#"{"features":[{"attributes":{"SERVICECODEDESCRIPTION":"Bulk Collection","REQUEST_COUNT":7}},{"attributes":{"SERVICECODEDESCRIPTION":"Tree Pruning","REQUEST_COUNT":5}}]}"#)
        let client = TrendPageClient(current: current, previous: previous)
        let now = Date(timeIntervalSince1970: 1_783_980_000)
        let repository = ServiceRequest311TrendRepository(client: client, now: { now })
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))

        let snapshot = try await repository.trendSnapshot(coordinate: coordinate, radiusMiles: 0.5, days: 30)

        #expect(snapshot.categories == ["Bulk Collection", "Graffiti Removal", "Tree Pruning"])
        #expect(snapshot.trends.contains { $0.category == "Graffiti Removal" && $0.direction == .newlyObserved })
        let queries = await client.queries
        #expect(queries.count == 2)
        #expect(queries.allSatisfy { $0.statistics.first?.statisticType == "count" })
        #expect(queries.allSatisfy { $0.groupByFieldsForStatistics == ["SERVICECODEDESCRIPTION"] })
        #expect(queries.allSatisfy { $0.point == .init(longitude: -77.0300, latitude: 38.9000) })
    }

    private func page(_ json: String) throws -> ArcGISFeaturePage {
        try JSONDecoder().decode(ArcGISFeaturePage.self, from: Data(json.utf8))
    }
}

private actor TrendPageClient: ArcGISClientProtocol {
    let current: ArcGISFeaturePage
    let previous: ArcGISFeaturePage
    private(set) var queries: [ArcGISQuery] = []

    init(current: ArcGISFeaturePage, previous: ArcGISFeaturePage) {
        self.current = current
        self.previous = previous
    }

    func fetchPage(from layerURL: URL, query: ArcGISQuery) async throws -> ArcGISFeaturePage {
        queries.append(query)
        return await query.whereClause.contains("ADDDATE < TIMESTAMP") ? previous : current
    }
}

import Foundation
import Testing
@testable import DCPulse

@MainActor
struct ServiceRequest311SummaryRepositoryTests {
    @Test func requestsCompleteMutuallyExclusiveStatusCounts() async throws {
        let client = SummaryCountClient()
        let now = Date(timeIntervalSince1970: 1_783_980_000)
        let repository = ServiceRequest311SummaryRepository(client: client, now: { now })
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.9000, longitude: -77.0300))

        let counts = try await repository.statusCounts(coordinate: coordinate, radiusMiles: 0.5, days: 30)

        #expect(counts == .init(new: 14, active: 189, resolved: 87))
        let queries = await client.queries
        #expect(queries.count == 3)
        #expect(queries.allSatisfy { $0.point == .init(longitude: -77.0300, latitude: 38.9000) })
        #expect(queries.allSatisfy { $0.radiusMiles == 0.5 && $0.returnCountOnly && !$0.returnGeometry })
        #expect(queries.contains { $0.whereClause.contains("ADDDATE >= TIMESTAMP") && $0.whereClause.contains("Open%") })
        #expect(queries.contains { $0.whereClause.contains("ADDDATE < TIMESTAMP") && $0.whereClause.contains("Open%") })
        #expect(queries.contains { $0.whereClause.contains("Close%") })
    }
}

private actor SummaryCountClient: ArcGISCountClientProtocol {
    private(set) var queries: [ArcGISQuery] = []

    func fetchCount(from layerURL: URL, query: ArcGISQuery) async throws -> Int {
        queries.append(query)
        let whereClause = await query.whereClause
        if whereClause.contains("ADDDATE < TIMESTAMP") { return 189 }
        if whereClause.contains("Close%") { return 87 }
        return 14
    }
}

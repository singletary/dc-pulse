import Foundation
import Testing
@testable import DCPulse

@MainActor
struct ArcGISQueryTests {
    @Test func constructsSpatialPaginationAndOrderingQuery() throws {
        let query = ArcGISQuery(
            whereClause: "OPENED >= 123",
            outputFields: ["OBJECTID", "STATUS"],
            point: .init(longitude: -77.08, latitude: 38.89),
            radiusMiles: 1,
            returnGeometry: true,
            resultOffset: 20,
            resultRecordCount: 100,
            orderByFields: ["OPENED DESC"]
        )
        let url = try query.url(for: #require(URL(string: "https://example.gov/FeatureServer/0")))
        let values = Dictionary(uniqueKeysWithValues: try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems).map { ($0.name, $0.value) })
        #expect(url.path.hasSuffix("/FeatureServer/0/query"))
        #expect(values["geometry"] == "-77.08,38.89")
        #expect(values["inSR"] == "4326")
        #expect(values["distance"] == "1.0")
        #expect(values["units"] == "esriSRUnit_StatuteMile")
        #expect(values["outSR"] == "4326")
        #expect(values["resultOffset"] == "20")
        #expect(values["orderByFields"] == "OPENED DESC")
        #expect(values["f"] == "json")
    }

    @Test func radiusRequiresCoordinate() {
        #expect(throws: ArcGISClientError.invalidRequest) {
            try ArcGISQuery(radiusMiles: 1).url(for: #require(URL(string: "https://example.gov/0")))
        }
    }

    @Test func constructsCountOnlyQuery() throws {
        let query = ArcGISQuery(returnGeometry: false, returnCountOnly: true)
        let url = try query.url(for: #require(URL(string: "https://example.gov/FeatureServer/0")))
        let values = Dictionary(uniqueKeysWithValues: try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems).map { ($0.name, $0.value) })

        #expect(values["returnCountOnly"] == "true")
        #expect(values["returnGeometry"] == "false")
    }

    @Test func constructsGroupedStatisticsQuery() throws {
        let query = ArcGISQuery(
            outputFields: [],
            returnGeometry: false,
            orderByFields: ["request_count DESC"],
            statistics: [
                .init(statisticType: "count", onStatisticField: "ID", outStatisticFieldName: "request_count")
            ],
            groupByFieldsForStatistics: ["CATEGORY"]
        )
        let url = try query.url(for: #require(URL(string: "https://example.gov/FeatureServer/0")))
        let values = Dictionary(uniqueKeysWithValues: try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems).map { ($0.name, $0.value) })
        let statistics = try #require(values["outStatistics"] ?? nil)

        #expect(values["outFields"] == nil)
        #expect(values["groupByFieldsForStatistics"] == "CATEGORY")
        #expect(statistics.contains(#""statisticType":"count""#))
        #expect(statistics.contains(#""outStatisticFieldName":"request_count""#))
    }
}

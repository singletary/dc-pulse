import Foundation

struct ServiceRequest311TrendRepository: RequestTrendSummaryRepositoryProtocol, Sendable {
    private let client: any ArcGISClientProtocol
    private let now: @Sendable () -> Date

    init(
        client: any ArcGISClientProtocol = URLSessionArcGISClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.client = client
        self.now = now
    }

    func trendSnapshot(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async throws -> RequestTrendSnapshot {
        let currentDate = now()
        let calendar = Calendar(identifier: .gregorian)
        let periodStart = calendar.date(byAdding: .day, value: -days, to: currentDate) ?? currentDate
        let midpoint = calendar.date(byAdding: .day, value: -(days / 2), to: currentDate) ?? currentDate
        let currentClause = "ADDDATE >= TIMESTAMP '\(Self.timestampFormatter.string(from: midpoint))' AND ADDDATE <= TIMESTAMP '\(Self.timestampFormatter.string(from: currentDate))'"
        let previousClause = "ADDDATE >= TIMESTAMP '\(Self.timestampFormatter.string(from: periodStart))' AND ADDDATE < TIMESTAMP '\(Self.timestampFormatter.string(from: midpoint))'"

        async let current = counts(where: currentClause, coordinate: coordinate, radiusMiles: radiusMiles)
        async let previous = counts(where: previousClause, coordinate: coordinate, radiusMiles: radiusMiles)
        return try await RequestTrendAnalyzer.snapshot(currentCounts: current, previousCounts: previous)
    }

    private func counts(
        where whereClause: String,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double
    ) async throws -> [String: Int] {
        let query = ArcGISQuery(
            whereClause: whereClause,
            outputFields: [],
            point: .init(longitude: coordinate.longitude, latitude: coordinate.latitude),
            radiusMiles: radiusMiles,
            returnGeometry: false,
            orderByFields: ["request_count DESC"],
            statistics: [
                .init(
                    statisticType: "count",
                    onStatisticField: "SERVICEREQUESTID",
                    outStatisticFieldName: "request_count"
                )
            ],
            groupByFieldsForStatistics: ["SERVICECODEDESCRIPTION"]
        )
        let page = try await client.fetchPage(from: ServiceRequest311Adapter.sourceURL, query: query)
        return Dictionary(uniqueKeysWithValues: page.features.compactMap { feature in
            guard let category = feature.attributes.string(caseInsensitive: "SERVICECODEDESCRIPTION"),
                  let count = feature.attributes.number(caseInsensitive: "request_count") else { return nil }
            return (category, Int(count))
        })
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private extension Dictionary where Key == String, Value == JSONValue {
    func string(caseInsensitive key: String) -> String? {
        guard let value = first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value,
              case .string(let string) = value else { return nil }
        return string
    }

    func number(caseInsensitive key: String) -> Double? {
        guard let value = first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value,
              case .number(let number) = value else { return nil }
        return number
    }
}

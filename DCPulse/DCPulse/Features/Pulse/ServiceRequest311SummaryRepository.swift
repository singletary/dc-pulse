import Foundation

struct ServiceRequest311SummaryRepository: RequestStatusSummaryRepositoryProtocol, Sendable {
    private let client: any ArcGISCountClientProtocol
    private let now: @Sendable () -> Date

    init(
        client: any ArcGISCountClientProtocol = URLSessionArcGISClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.client = client
        self.now = now
    }

    func statusCounts(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async throws -> RequestStatusCounts {
        let currentDate = now()
        let calendar = Calendar(identifier: .gregorian)
        let periodCutoff = calendar.date(byAdding: .day, value: -days, to: currentDate) ?? currentDate
        let newCutoff = currentDate.addingTimeInterval(-48 * 60 * 60)
        let clauses = ServiceRequest311StatusClauses(periodCutoff: periodCutoff, newCutoff: newCutoff)

        async let newCount = count(where: clauses.whereClause(for: .new), coordinate: coordinate, radiusMiles: radiusMiles)
        async let activeCount = count(where: clauses.whereClause(for: .active), coordinate: coordinate, radiusMiles: radiusMiles)
        async let resolvedCount = count(where: clauses.whereClause(for: .resolved), coordinate: coordinate, radiusMiles: radiusMiles)
        return try await RequestStatusCounts(new: newCount, active: activeCount, resolved: resolvedCount)
    }

    private func count(
        where whereClause: String,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double
    ) async throws -> Int {
        let query = ArcGISQuery(
            whereClause: whereClause,
            outputFields: [],
            point: .init(longitude: coordinate.longitude, latitude: coordinate.latitude),
            radiusMiles: radiusMiles,
            returnGeometry: false,
            returnCountOnly: true
        )
        return try await client.fetchCount(from: ServiceRequest311Adapter.sourceURL, query: query)
    }

}

struct ServiceRequest311CategorySummaryRepository: RequestCategorySummaryRepositoryProtocol, Sendable {
    private let client: any ArcGISClientProtocol
    private let now: @Sendable () -> Date

    init(
        client: any ArcGISClientProtocol = URLSessionArcGISClient(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.client = client
        self.now = now
    }

    func categoryCounts(
        status: PulseItem.Status?,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async throws -> [String: Int] {
        let currentDate = now()
        let periodCutoff = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -days,
            to: currentDate
        ) ?? currentDate
        let clauses = ServiceRequest311StatusClauses(
            periodCutoff: periodCutoff,
            newCutoff: currentDate.addingTimeInterval(-48 * 60 * 60)
        )
        let query = ArcGISQuery(
            whereClause: clauses.whereClause(for: status),
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
            guard let category = feature.attributes.first(where: {
                $0.key.caseInsensitiveCompare("SERVICECODEDESCRIPTION") == .orderedSame
            })?.value.stringValue,
                  let count = feature.attributes.first(where: {
                      $0.key.caseInsensitiveCompare("request_count") == .orderedSame
                  })?.value.numberValue else { return nil }
            return (category, Int(count))
        })
    }
}

private struct ServiceRequest311StatusClauses {
    let periodClause: String
    let newCutoffClause: String

    init(periodCutoff: Date, newCutoff: Date) {
        periodClause = "ADDDATE >= TIMESTAMP '\(Self.timestampFormatter.string(from: periodCutoff))'"
        newCutoffClause = "TIMESTAMP '\(Self.timestampFormatter.string(from: newCutoff))'"
    }

    func whereClause(for status: PulseItem.Status?) -> String {
        switch status {
        case .new:
            "\(periodClause) AND ADDDATE >= \(newCutoffClause) AND \(Self.unresolvedClause)"
        case .active:
            "\(periodClause) AND ADDDATE < \(newCutoffClause) AND \(Self.unresolvedClause)"
        case .resolved:
            "\(periodClause) AND \(Self.resolvedClause)"
        case .unknown:
            "\(periodClause) AND NOT (\(Self.unresolvedClause) OR \(Self.resolvedClause))"
        case nil:
            periodClause
        }
    }

    private static let unresolvedClause = "(SERVICEORDERSTATUS LIKE 'Open%' OR SERVICEORDERSTATUS LIKE 'In-Progress%' OR SERVICEORDERSTATUS LIKE 'Assigned%' OR SERVICEORDERSTATUS LIKE 'New%')"
    private static let resolvedClause = "(SERVICEORDERSTATUS LIKE 'Close%' OR SERVICEORDERSTATUS LIKE 'Complete%' OR SERVICEORDERSTATUS LIKE 'Resolve%')"

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private extension JSONValue {
    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }
}

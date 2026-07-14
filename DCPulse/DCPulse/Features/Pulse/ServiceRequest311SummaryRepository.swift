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
        let periodClause = "ADDDATE >= TIMESTAMP '\(Self.timestampFormatter.string(from: periodCutoff))'"
        let newClause = "\(periodClause) AND ADDDATE >= TIMESTAMP '\(Self.timestampFormatter.string(from: newCutoff))' AND \(Self.unresolvedClause)"
        let activeClause = "\(periodClause) AND ADDDATE < TIMESTAMP '\(Self.timestampFormatter.string(from: newCutoff))' AND \(Self.unresolvedClause)"
        let resolvedClause = "\(periodClause) AND \(Self.resolvedClause)"

        async let newCount = count(where: newClause, coordinate: coordinate, radiusMiles: radiusMiles)
        async let activeCount = count(where: activeClause, coordinate: coordinate, radiusMiles: radiusMiles)
        async let resolvedCount = count(where: resolvedClause, coordinate: coordinate, radiusMiles: radiusMiles)
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

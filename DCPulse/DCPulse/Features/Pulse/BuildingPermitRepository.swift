import Foundation

struct BuildingPermitRepository: PulseRepositoryProtocol, WatchedItemRefreshRepositoryProtocol, Sendable {
    private let client: any ArcGISClientProtocol
    private let now: @Sendable () -> Date
    private let adapter: BuildingPermitAdapter

    init(client: any ArcGISClientProtocol = URLSessionArcGISClient(), now: @escaping @Sendable () -> Date = { .now }) {
        self.client = client
        self.now = now
        adapter = BuildingPermitAdapter(now: now)
    }

    var source: PulseItem.Source { .buildingPermits2026 }

    func items(withIdentifiers identifiers: [String]) async throws -> [PulseItem] {
        guard !identifiers.isEmpty else { return [] }
        let query = ArcGISQuery(
            whereClause: "PERMIT_ID IN (\(ArcGISWhereClause.quotedList(identifiers)))",
            outputFields: Self.outputFields,
            returnGeometry: true,
            resultRecordCount: identifiers.count
        )
        let page = try await client.fetchPage(from: BuildingPermitAdapter.sourceURL, query: query)
        return page.features.compactMap { try? adapter.map($0) }
    }

    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) async throws -> PulsePage {
        let cutoff = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: now()) ?? now()
        let query = ArcGISQuery(
            whereClause: "ISSUE_DATE >= DATE '\(Self.dateFormatter.string(from: cutoff))'",
            outputFields: Self.outputFields,
            point: .init(longitude: coordinate.longitude, latitude: coordinate.latitude),
            radiusMiles: radiusMiles,
            returnGeometry: true,
            resultOffset: offset,
            resultRecordCount: limit,
            orderByFields: ["ISSUE_DATE DESC"]
        )
        let page = try await client.fetchPage(from: BuildingPermitAdapter.sourceURL, query: query)
        return PulsePage(
            items: page.features.compactMap { try? adapter.map($0) },
            nextOffset: offset + page.features.count,
            hasMore: page.exceededTransferLimit == true
        )
    }

    private static let outputFields = [
        "PERMIT_ID", "PERMIT_TYPE_NAME", "PERMIT_SUBTYPE_NAME", "PERMIT_CATEGORY_NAME",
        "APPLICATION_STATUS_NAME", "FULL_ADDRESS", "DESC_OF_WORK", "ISSUE_DATE", "LASTMODIFIEDDATE",
        "WARD", "NEIGHBORHOODCLUSTER", "LATITUDE", "LONGITUDE", "FEES_PAID", "ZONING", "SSL"
    ]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

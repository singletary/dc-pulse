import Foundation

struct DDOTConstructionPermitRepository: PulseRepositoryProtocol, WatchedItemRefreshRepositoryProtocol, Sendable {
    private let client: any ArcGISClientProtocol
    private let now: @Sendable () -> Date
    private let adapter: DDOTConstructionPermitAdapter

    init(client: any ArcGISClientProtocol = URLSessionArcGISClient(), now: @escaping @Sendable () -> Date = { .now }) {
        self.client = client
        self.now = now
        adapter = DDOTConstructionPermitAdapter(now: now)
    }

    var source: PulseItem.Source { .ddotConstructionPermits2026 }

    func items(withIdentifiers identifiers: [String]) async throws -> [PulseItem] {
        guard !identifiers.isEmpty else { return [] }
        let values = ArcGISWhereClause.quotedList(identifiers)
        let query = ArcGISQuery(
            whereClause: "PERMITNUMBER IN (\(values)) OR TRACKINGNUMBER IN (\(values))",
            outputFields: Self.outputFields,
            returnGeometry: true,
            resultRecordCount: identifiers.count
        )
        let page = try await client.fetchPage(from: DDOTConstructionPermitAdapter.sourceURL, query: query)
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
            whereClause: "APPLICATIONDATE >= DATE '\(Self.dateFormatter.string(from: cutoff))'",
            outputFields: Self.outputFields,
            point: .init(longitude: coordinate.longitude, latitude: coordinate.latitude),
            radiusMiles: radiusMiles,
            returnGeometry: true,
            resultOffset: offset,
            resultRecordCount: limit,
            orderByFields: ["APPLICATIONDATE DESC"]
        )
        let page = try await client.fetchPage(from: DDOTConstructionPermitAdapter.sourceURL, query: query)
        return PulsePage(
            items: page.features.compactMap { try? adapter.map($0) },
            nextOffset: offset + page.features.count,
            hasMore: page.exceededTransferLimit == true
        )
    }

    private static let outputFields = [
        "TRACKINGNUMBER", "PERMITNUMBER", "APPLICATIONDATE", "ISSUEDATE", "EFFECTIVEDATE",
        "EXPIRATIONDATE", "STATUS", "WLFULLADDRESS", "PERMITTEENAME", "WORKDETAIL",
        "ISEXCAVATION", "ISFIXTURE", "ISPAVING", "ISLANDSCAPING", "ISPROJECTIONS", "ISPSRENTAL",
        "LATITUDE", "LONGITUDE", "EDITED"
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

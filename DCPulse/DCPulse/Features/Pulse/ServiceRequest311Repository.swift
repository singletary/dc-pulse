import Foundation

protocol PulseRepositoryProtocol: Sendable {
    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) async throws -> PulsePage
}

protocol ServiceRequestCategoryRepositoryProtocol: Sendable {
    func items(
        in category: String,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        limit: Int
    ) async throws -> [PulseItem]
}

struct PulsePage: Equatable, Sendable {
    let items: [PulseItem]
    let nextOffset: Int
    let hasMore: Bool
    var warnings: [String] = []
}

struct ServiceRequest311Repository: PulseRepositoryProtocol, WatchedItemRefreshRepositoryProtocol, ServiceRequestCategoryRepositoryProtocol, Sendable {
    private let client: any ArcGISClientProtocol
    private let now: @Sendable () -> Date
    private let adapter: ServiceRequest311Adapter

    init(client: any ArcGISClientProtocol = URLSessionArcGISClient(), now: @escaping @Sendable () -> Date = { .now }) {
        self.client = client
        self.now = now
        adapter = ServiceRequest311Adapter(now: now)
    }

    var source: PulseItem.Source { .serviceRequests311 }

    func items(withIdentifiers identifiers: [String]) async throws -> [PulseItem] {
        guard !identifiers.isEmpty else { return [] }
        let query = ArcGISQuery(
            whereClause: "SERVICEREQUESTID IN (\(ArcGISWhereClause.quotedList(identifiers)))",
            outputFields: Self.outputFields,
            returnGeometry: true,
            resultRecordCount: identifiers.count
        )
        let page = try await client.fetchPage(from: ServiceRequest311Adapter.sourceURL, query: query)
        return page.features.compactMap { try? adapter.map($0) }
    }

    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) async throws -> PulsePage {
        let query = nearbyQuery(
            coordinate: coordinate,
            radiusMiles: radiusMiles,
            days: days,
            offset: offset,
            limit: limit
        )
        let page = try await client.fetchPage(from: ServiceRequest311Adapter.sourceURL, query: query)
        return PulsePage(
            items: page.features.compactMap { try? adapter.map($0) },
            nextOffset: offset + page.features.count,
            hasMore: page.exceededTransferLimit == true
        )
    }

    func items(
        in category: String,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        limit: Int
    ) async throws -> [PulseItem] {
        let categoryClause = "SERVICECODEDESCRIPTION IN (\(ArcGISWhereClause.quotedList([category])))"
        let query = nearbyQuery(
            coordinate: coordinate,
            radiusMiles: radiusMiles,
            days: days,
            offset: 0,
            limit: limit,
            additionalWhereClause: categoryClause
        )
        let page = try await client.fetchPage(from: ServiceRequest311Adapter.sourceURL, query: query)
        return page.features.compactMap { try? adapter.map($0) }
    }

    private func nearbyQuery(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int,
        additionalWhereClause: String? = nil
    ) -> ArcGISQuery {
        let cutoff = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: now()) ?? now()
        var whereClause = "ADDDATE >= DATE '\(Self.dateFormatter.string(from: cutoff))'"
        if let additionalWhereClause { whereClause += " AND \(additionalWhereClause)" }
        return ArcGISQuery(
            whereClause: whereClause,
            outputFields: Self.outputFields,
            point: .init(longitude: coordinate.longitude, latitude: coordinate.latitude),
            radiusMiles: radiusMiles,
            returnGeometry: true,
            resultOffset: offset,
            resultRecordCount: limit,
            orderByFields: ["ADDDATE DESC"]
        )
    }

    private static let outputFields = [
        "SERVICEREQUESTID", "SERVICECODEDESCRIPTION", "SERVICETYPECODEDESCRIPTION", "ORGANIZATIONACRONYM",
        "ADDDATE", "RESOLUTIONDATE", "SERVICEORDERSTATUS", "STATUS_CODE", "DETAILS", "PRIORITY",
        "STREETADDRESS", "WARD", "EDITED", "LATITUDE", "LONGITUDE"
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

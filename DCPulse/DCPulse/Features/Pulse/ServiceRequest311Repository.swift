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

struct PulsePage: Equatable, Sendable {
    let items: [PulseItem]
    let nextOffset: Int
    let hasMore: Bool
}

struct ServiceRequest311Repository: PulseRepositoryProtocol, Sendable {
    private let client: any ArcGISClientProtocol
    private let now: @Sendable () -> Date
    private let adapter = ServiceRequest311Adapter()

    init(client: any ArcGISClientProtocol = URLSessionArcGISClient(), now: @escaping @Sendable () -> Date = { .now }) {
        self.client = client
        self.now = now
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
            whereClause: "ADDDATE >= DATE '\(Self.dateFormatter.string(from: cutoff))'",
            outputFields: Self.outputFields,
            point: .init(longitude: coordinate.longitude, latitude: coordinate.latitude),
            radiusMiles: radiusMiles,
            returnGeometry: true,
            resultOffset: offset,
            resultRecordCount: limit,
            orderByFields: ["ADDDATE DESC"]
        )
        let page = try await client.fetchPage(from: ServiceRequest311Adapter.sourceURL, query: query)
        return PulsePage(
            items: page.features.compactMap { try? adapter.map($0) },
            nextOffset: offset + page.features.count,
            hasMore: page.exceededTransferLimit == true
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

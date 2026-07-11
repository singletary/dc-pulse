import Foundation

protocol PulseRepositoryProtocol: Sendable {
    func nearbyItems(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int) async throws -> [PulseItem]
}

struct ServiceRequest311Repository: PulseRepositoryProtocol, Sendable {
    private let client: any ArcGISClientProtocol
    private let now: @Sendable () -> Date
    private let adapter = ServiceRequest311Adapter()

    init(client: any ArcGISClientProtocol = URLSessionArcGISClient(), now: @escaping @Sendable () -> Date = { .now }) {
        self.client = client
        self.now = now
    }

    func nearbyItems(coordinate: PulseItem.Coordinate, radiusMiles: Double, days: Int) async throws -> [PulseItem] {
        let cutoff = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: now()) ?? now()
        let query = ArcGISQuery(
            whereClause: "ADDDATE >= DATE '\(Self.dateFormatter.string(from: cutoff))'",
            outputFields: Self.outputFields,
            point: .init(longitude: coordinate.longitude, latitude: coordinate.latitude),
            radiusMiles: radiusMiles,
            returnGeometry: true,
            resultOffset: 0,
            resultRecordCount: 500,
            orderByFields: ["ADDDATE DESC"]
        )
        let features = try await ArcGISPaginator(client: client).fetchAll(from: ServiceRequest311Adapter.sourceURL, query: query)
        return features.compactMap { try? adapter.map($0) }
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

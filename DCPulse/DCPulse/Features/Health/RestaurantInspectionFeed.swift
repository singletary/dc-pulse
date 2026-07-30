import Foundation

struct RestaurantInspectionFeed: Decodable, Sendable {
    static let supportedVersion = 1
    static let expectedSchema = "dc-pulse.restaurant-inspections.v1"

    struct Record: Decodable, Sendable {
        let permitIdentifier: String
        let inspectionIdentifier: String
        let establishmentName: String
        let address: String
        let ward: String?
        let latitude: Double
        let longitude: Double
        let inspectionDate: Date
        let inspectionType: String
        let outcome: RestaurantInspection.Outcome
        let priorityViolations: Int
        let priorityFoundationViolations: Int
        let coreViolations: Int
        let reportURL: URL
    }

    let version: Int
    let schema: String
    let generatedAt: Date
    let attribution: String
    let sourceURL: URL
    let records: [Record]
}

struct RestaurantInspectionFeedPolicy: Equatable, Sendable {
    let isEnabled: Bool
    let maximumAge: TimeInterval

    init(isEnabled: Bool, maximumAge: TimeInterval) {
        self.isEnabled = isEnabled
        self.maximumAge = maximumAge
    }
}

enum RestaurantInspectionFeedError: Error, Equatable {
    case disabled
    case invalidPolicy
    case decoding
    case unsupportedVersion(Int)
    case unexpectedSchema(String)
    case futureFeed
    case staleFeed
    case invalidAttribution
    case invalidSourceURL
    case invalidRecord(index: Int)
}

struct RestaurantInspectionFeedAdapter: Sendable {
    let policy: RestaurantInspectionFeedPolicy

    func map(_ data: Data, now: Date) throws -> [RestaurantInspection] {
        guard policy.isEnabled else { throw RestaurantInspectionFeedError.disabled }
        guard policy.maximumAge.isFinite, policy.maximumAge > 0 else {
            throw RestaurantInspectionFeedError.invalidPolicy
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let feed: RestaurantInspectionFeed
        do {
            feed = try decoder.decode(RestaurantInspectionFeed.self, from: data)
        } catch {
            throw RestaurantInspectionFeedError.decoding
        }

        guard feed.version == RestaurantInspectionFeed.supportedVersion else {
            throw RestaurantInspectionFeedError.unsupportedVersion(feed.version)
        }
        guard feed.schema == RestaurantInspectionFeed.expectedSchema else {
            throw RestaurantInspectionFeedError.unexpectedSchema(feed.schema)
        }
        let age = now.timeIntervalSince(feed.generatedAt)
        guard age >= 0 else { throw RestaurantInspectionFeedError.futureFeed }
        guard age <= policy.maximumAge else { throw RestaurantInspectionFeedError.staleFeed }
        guard !feed.attribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RestaurantInspectionFeedError.invalidAttribution
        }
        guard Self.isSecureHTTPURL(feed.sourceURL) else {
            throw RestaurantInspectionFeedError.invalidSourceURL
        }

        return try feed.records.enumerated().map { index, record in
            try map(record, feed: feed, index: index)
        }
    }

    private func map(
        _ record: RestaurantInspectionFeed.Record,
        feed: RestaurantInspectionFeed,
        index: Int
    ) throws -> RestaurantInspection {
        let requiredText = [
            record.permitIdentifier,
            record.inspectionIdentifier,
            record.establishmentName,
            record.address,
            record.inspectionType
        ]
        guard requiredText.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              record.priorityViolations >= 0,
              record.priorityFoundationViolations >= 0,
              record.coreViolations >= 0,
              record.inspectionDate <= feed.generatedAt,
              let coordinate = PulseItem.Coordinate(
                latitude: record.latitude,
                longitude: record.longitude
              ),
              coordinate.isWithinDCServiceArea,
              Self.isSecureHTTPURL(record.reportURL) else {
            throw RestaurantInspectionFeedError.invalidRecord(index: index)
        }

        return RestaurantInspection(
            id: .init(
                permitIdentifier: record.permitIdentifier,
                inspectionIdentifier: record.inspectionIdentifier
            ),
            establishmentName: record.establishmentName,
            address: record.address,
            ward: record.ward,
            coordinate: coordinate,
            inspectionDate: record.inspectionDate,
            inspectionType: record.inspectionType,
            outcome: record.outcome,
            violations: .init(
                priority: record.priorityViolations,
                priorityFoundation: record.priorityFoundationViolations,
                core: record.coreViolations
            ),
            reportURL: record.reportURL,
            feedGeneratedAt: feed.generatedAt,
            attribution: feed.attribution,
            sourceURL: feed.sourceURL
        )
    }

    private static func isSecureHTTPURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host != nil
    }
}

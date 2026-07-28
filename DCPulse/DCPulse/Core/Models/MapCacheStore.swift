import Foundation

nonisolated struct MapCacheContext: Codable, Hashable, Sendable {
    static let schemaGeneration = 1

    let latitudeBucket: Int
    let longitudeBucket: Int
    let radiusMiles: Double
    let periodDays: Int
    let generation: Int

    init(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        periodDays: Int,
        generation: Int = Self.schemaGeneration
    ) {
        // Three decimal places is roughly a city block. It prevents exact
        // coordinates from becoming archive keys while keeping nearby searches
        // from accidentally reusing a distant context.
        latitudeBucket = Int((coordinate.latitude * 1_000).rounded())
        longitudeBucket = Int((coordinate.longitude * 1_000).rounded())
        self.radiusMiles = radiusMiles
        self.periodDays = periodDays
        self.generation = generation
    }
}

nonisolated struct MapCacheRecord: Codable, Equatable, Sendable {
    let context: MapCacheContext
    let savedAt: Date
    let itemCount: Int
    let payload: Data
}

nonisolated struct MapCachePolicy: Equatable, Sendable {
    let maximumEntries: Int
    let maximumTotalItems: Int
    let maximumTotalBytes: Int
    let maximumAge: TimeInterval

    static let production = MapCachePolicy(
        maximumEntries: 6,
        maximumTotalItems: 3_600,
        maximumTotalBytes: 16 * 1_024 * 1_024,
        maximumAge: 24 * 60 * 60
    )
}

nonisolated enum MapCacheStoreError: Error, Equatable {
    case invalidPolicy
    case invalidItemCount
    case recordExceedsItemLimit
    case recordExceedsByteLimit
}

nonisolated protocol MapCacheStoreProtocol: Sendable {
    func record(for context: MapCacheContext) async -> MapCacheRecord?
    func mostRecentRecord() async -> MapCacheRecord?
    func save(_ record: MapCacheRecord) async throws
}

actor FileBackedMapCacheStore: MapCacheStoreProtocol {
    private struct Archive: Codable {
        static let currentVersion = 1

        let version: Int
        let records: [MapCacheRecord]
    }

    private let fileURL: URL
    private let policy: MapCachePolicy
    private let now: @Sendable () -> Date

    init(
        fileURL: URL = FileBackedMapCacheStore.defaultFileURL,
        policy: MapCachePolicy = .production,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.fileURL = fileURL
        self.policy = policy
        self.now = now
    }

    func record(for context: MapCacheContext) -> MapCacheRecord? {
        validRecords().first { $0.context == context }
    }

    func mostRecentRecord() -> MapCacheRecord? {
        validRecords().first
    }

    func save(_ record: MapCacheRecord) throws {
        guard policy.maximumEntries > 0,
              policy.maximumTotalItems > 0,
              policy.maximumTotalBytes > 0,
              policy.maximumAge > 0 else {
            throw MapCacheStoreError.invalidPolicy
        }
        guard record.itemCount >= 0 else {
            throw MapCacheStoreError.invalidItemCount
        }
        guard record.itemCount <= policy.maximumTotalItems else {
            throw MapCacheStoreError.recordExceedsItemLimit
        }
        guard record.payload.count <= policy.maximumTotalBytes else {
            throw MapCacheStoreError.recordExceedsByteLimit
        }

        var candidates = validRecords().filter { $0.context != record.context }
        candidates.append(record)
        let bounded = Self.boundedRecords(
            candidates,
            policy: policy,
            referenceDate: now()
        )
        try persist(bounded)
    }

    private func validRecords() -> [MapCacheRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let archive = try? JSONDecoder().decode(Archive.self, from: data),
              archive.version == Archive.currentVersion else {
            return []
        }
        return Self.boundedRecords(
            archive.records,
            policy: policy,
            referenceDate: now()
        )
    }

    private func persist(_ records: [MapCacheRecord]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let archive = Archive(version: Archive.currentVersion, records: records)
        let data = try JSONEncoder().encode(archive)
        try data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUnlessOpen]
        )
    }

    private static func boundedRecords(
        _ records: [MapCacheRecord],
        policy: MapCachePolicy,
        referenceDate: Date
    ) -> [MapCacheRecord] {
        guard policy.maximumEntries > 0,
              policy.maximumTotalItems > 0,
              policy.maximumTotalBytes > 0,
              policy.maximumAge > 0 else {
            return []
        }

        let cutoff = referenceDate.addingTimeInterval(-policy.maximumAge)
        let sorted = records
            .filter { $0.savedAt >= cutoff && $0.itemCount >= 0 }
            .sorted { $0.savedAt > $1.savedAt }

        var result: [MapCacheRecord] = []
        var seenContexts: Set<MapCacheContext> = []
        var totalItems = 0
        var totalBytes = 0
        for record in sorted where result.count < policy.maximumEntries {
            guard !seenContexts.contains(record.context),
                  totalItems + record.itemCount <= policy.maximumTotalItems,
                  totalBytes + record.payload.count <= policy.maximumTotalBytes else {
                continue
            }
            result.append(record)
            seenContexts.insert(record.context)
            totalItems += record.itemCount
            totalBytes += record.payload.count
        }
        return result
    }

    nonisolated private static var defaultFileURL: URL {
        let cachesURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return cachesURL
            .appendingPathComponent("DCPulse", isDirectory: true)
            .appendingPathComponent("map-cache-v1.json", isDirectory: false)
    }
}

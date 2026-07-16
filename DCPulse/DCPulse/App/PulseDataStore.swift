import Foundation
import Observation

@MainActor @Observable
final class PulseDataStore {
    static let pageSize = 30
    static let summaryLimit = 150
    static let mapPageSize = 150
    static let mapResultLimit = 600
    static let cacheLifetime: TimeInterval = 10 * 60

    private struct CacheEntry: Codable {
        let savedAt: Date
        let coordinate: PulseItem.Coordinate
        let radius: Radius
        let period: Period
        let placeName: String
        let items: [PulseItem]
        let nextOffset: Int
        let hasMore: Bool
        let warnings: [String]
        let requestStatusCounts: RequestStatusCounts?
        let requestTrendSnapshot: RequestTrendSnapshot?
    }

    enum Period: Int, CaseIterable, Identifiable, Codable {
        case thirtyDays = 30
        case ninetyDays = 90
        case sixMonths = 180
        case yearToDate = 0

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .thirtyDays: "30 days"
            case .ninetyDays: "90 days"
            case .sixMonths: "6 months"
            case .yearToDate: "Year to date"
            }
        }
        var queryDays: Int {
            guard self == .yearToDate else { return rawValue }
            let calendar = Calendar(identifier: .gregorian)
            let start = calendar.dateInterval(of: .year, for: .now)?.start ?? .now
            return max(1, calendar.dateComponents([.day], from: start, to: .now).day ?? 1)
        }
    }

    enum Radius: Double, CaseIterable, Identifiable, Codable {
        case quarterMile = 0.25
        case halfMile = 0.5
        case oneMile = 1

        var id: Double { rawValue }
        var label: String { rawValue == 1 ? "1 mile" : "\(rawValue.formatted()) mile" }
    }

    enum State: Equatable { case idle, loading, loaded, empty, failed(String) }

    private let repository: any PulseRepositoryProtocol
    private let requestStatusSummaryRepository: (any RequestStatusSummaryRepositoryProtocol)?
    private let requestTrendSummaryRepository: (any RequestTrendSummaryRepositoryProtocol)?
    private let requestCategoryRepository: (any ServiceRequestCategoryRepositoryProtocol)?
    private let defaults: UserDefaults
    private let now: () -> Date
    private var loadSequence = 0
    private var mapCoverageSequence = 0
    private var nextOffset = 0
    var items: [PulseItem] = []
    var state: State = .idle
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var isMapCoverageLoading = false
    private(set) var loadMoreError: String?
    private(set) var sourceWarnings: [String] = []
    private(set) var requestStatusCounts: RequestStatusCounts?
    private(set) var isRequestSummaryLoading = false
    private(set) var requestTrendSnapshot: RequestTrendSnapshot?
    private(set) var isRequestInsightsLoading = false
    private(set) var searchCoordinate = SampleData.center
    private(set) var placeName = "Downtown DC"
    private(set) var radius: Radius = .halfMile
    private(set) var period: Period = .thirtyDays

    init() {
        repository = CombinedPulseRepository(sources: [
            NamedPulseRepository(name: "DC 311", repository: ServiceRequest311Repository()),
            NamedPulseRepository(name: "Building Permits", repository: BuildingPermitRepository()),
            NamedPulseRepository(name: "DDOT Construction Permits", repository: DDOTConstructionPermitRepository())
        ])
        requestStatusSummaryRepository = ServiceRequest311SummaryRepository()
        requestTrendSummaryRepository = ServiceRequest311TrendRepository()
        requestCategoryRepository = ServiceRequest311Repository()
        defaults = .standard
        now = { .now }
    }

    init(
        repository: any PulseRepositoryProtocol,
        requestStatusSummaryRepository: (any RequestStatusSummaryRepositoryProtocol)? = nil,
        requestTrendSummaryRepository: (any RequestTrendSummaryRepositoryProtocol)? = nil,
        requestCategoryRepository: (any ServiceRequestCategoryRepositoryProtocol)? = nil,
        defaults: UserDefaults? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        self.repository = repository
        self.requestStatusSummaryRepository = requestStatusSummaryRepository
        self.requestTrendSummaryRepository = requestTrendSummaryRepository
        self.requestCategoryRepository = requestCategoryRepository
        self.defaults = defaults ?? UserDefaults(suiteName: "DCPulseTests.\(UUID().uuidString)")!
        self.now = now
    }

    func load(
        coordinate requestedCoordinate: PulseItem.Coordinate? = nil,
        placeName: String = "Downtown DC",
        force: Bool = false
    ) async {
        if requestedCoordinate == nil, !force, restoreMostRecentCache() { return }
        let coordinate = requestedCoordinate ?? SampleData.center
        let contextChanged = coordinate != searchCoordinate || placeName != self.placeName
        guard force || state == .idle || isFailure || contextChanged else { return }
        searchCoordinate = coordinate
        self.placeName = placeName
        loadSequence += 1
        let requestSequence = loadSequence
        state = .loading
        hasMore = false
        isLoadingMore = false
        loadMoreError = nil
        sourceWarnings = []
        requestStatusCounts = nil
        isRequestSummaryLoading = requestStatusSummaryRepository != nil
        requestTrendSnapshot = nil
        isRequestInsightsLoading = requestTrendSummaryRepository != nil
        nextOffset = 0
        if !force, restoreFreshCache(for: coordinate, placeName: placeName) { return }
        do {
            async let pageRequest = repository.nearbyItems(
                coordinate: coordinate,
                radiusMiles: radius.rawValue,
                days: period.queryDays,
                offset: 0,
                limit: Self.pageSize
            )
            async let countsRequest = Self.loadStatusCounts(
                using: requestStatusSummaryRepository,
                coordinate: coordinate,
                radiusMiles: radius.rawValue,
                days: period.queryDays
            )
            async let trendsRequest = Self.loadTrendSnapshot(
                using: requestTrendSummaryRepository,
                coordinate: coordinate,
                radiusMiles: radius.rawValue,
                days: period.queryDays
            )
            let page = try await pageRequest
            guard requestSequence == loadSequence else { return }
            items = page.items
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            sourceWarnings = page.warnings
            state = page.items.isEmpty ? .empty : .loaded
            saveCache()
            let counts = await countsRequest
            guard requestSequence == loadSequence else { return }
            requestStatusCounts = counts
            isRequestSummaryLoading = false
            saveCache()
            let trendSnapshot = await trendsRequest
            guard requestSequence == loadSequence else { return }
            requestTrendSnapshot = trendSnapshot
            isRequestInsightsLoading = false
            saveCache()
        } catch is CancellationError {
            guard requestSequence == loadSequence else { return }
            isRequestSummaryLoading = false
            isRequestInsightsLoading = false
            state = .idle
        } catch {
            guard requestSequence == loadSequence else { return }
            isRequestSummaryLoading = false
            isRequestInsightsLoading = false
            state = .failed(error.localizedDescription)
        }
    }

    func loadMore(limit: Int = 30, persistResult: Bool = true) async {
        guard state == .loaded, hasMore, !isLoadingMore else { return }
        let requestSequence = loadSequence
        let requestedOffset = nextOffset
        isLoadingMore = true
        loadMoreError = nil
        defer {
            if requestSequence == loadSequence { isLoadingMore = false }
        }

        do {
            let page = try await repository.nearbyItems(
                coordinate: searchCoordinate,
                radiusMiles: radius.rawValue,
                days: period.queryDays,
                offset: requestedOffset,
                limit: limit
            )
            guard requestSequence == loadSequence else { return }
            let existingIDs = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            sourceWarnings = Array(Set(sourceWarnings + page.warnings)).sorted()
            if persistResult { saveCache() }
        } catch is CancellationError {
            return
        } catch {
            guard requestSequence == loadSequence else { return }
            loadMoreError = error.localizedDescription
        }
    }

    func prefetchSummary(
        maximumItemCount: Int = 150,
        pageSize: Int = 30
    ) async {
        var loadedAdditionalItems = false
        while state == .loaded, hasMore, items.count < maximumItemCount, loadMoreError == nil {
            let previousCount = items.count
            await loadMore(limit: pageSize, persistResult: false)
            if items.count == previousCount { break }
            loadedAdditionalItems = true
        }
        if loadedAdditionalItems { saveCache() }
    }

    /// Prepares a denser, monotonic result set for the map. A larger search radius
    /// first includes the close-in quarter-mile results so zooming out cannot hide
    /// a nearby record merely because newer, farther-away records filled a page.
    func prepareMapResults() async {
        mapCoverageSequence += 1
        let coverageSequence = mapCoverageSequence
        let requestSequence = loadSequence
        let coordinate = searchCoordinate
        let selectedRadius = radius
        let selectedPeriod = period
        isMapCoverageLoading = true
        defer {
            if coverageSequence == mapCoverageSequence { isMapCoverageLoading = false }
        }

        do {
            if selectedRadius != .quarterMile {
                try await mergeCoverageItems(
                    coordinate: coordinate,
                    radius: .quarterMile,
                    period: selectedPeriod,
                    limit: Self.mapResultLimit,
                    requestSequence: requestSequence,
                    selectedRadius: selectedRadius
                )
                try Task.checkCancellation()
                guard requestSequence == loadSequence,
                      coordinate == searchCoordinate,
                      selectedRadius == radius,
                      selectedPeriod == period else { return }
            }

            await prefetchSummary(
                maximumItemCount: Self.mapResultLimit,
                pageSize: Self.mapPageSize
            )
            saveCache()
        } catch is CancellationError {
            return
        } catch {
            guard requestSequence == loadSequence else { return }
            sourceWarnings = Array(Set(sourceWarnings + [
                "Some close-in map results could not be verified. Pull to refresh and try again."
            ])).sorted()
        }
    }

    func retry() async {
        await load(coordinate: searchCoordinate, placeName: placeName, force: true)
        await prefetchSummary()
    }

    func selectRadius(_ radius: Radius) async {
        guard radius != self.radius else { return }
        self.radius = radius
        await load(coordinate: searchCoordinate, placeName: placeName, force: true)
    }

    func selectPeriod(_ period: Period) async {
        guard period != self.period else { return }
        self.period = period
        await load(coordinate: searchCoordinate, placeName: placeName, force: true)
    }

    func resetSearchOptions() async {
        guard radius != .halfMile || period != .thirtyDays else { return }
        radius = .halfMile
        period = .thirtyDays
        await load(coordinate: searchCoordinate, placeName: placeName, force: true)
    }

    var isLoading: Bool { state == .loading }
    var requestTrends: [RequestTrendAnalyzer.Trend] { requestTrendSnapshot?.trends ?? [] }
    var requestCategories: [String] { requestTrendSnapshot?.categories ?? [] }
    var requestCategoryCounts: [String: Int] { requestTrendSnapshot?.categoryCounts ?? [:] }

    func requestItems(in category: String, limit: Int = 250) async throws -> [PulseItem] {
        guard let requestCategoryRepository else {
            return items.filter { $0.id.source == .serviceRequests311 && $0.category == category }
        }
        return try await requestCategoryRepository.items(
            in: category,
            coordinate: searchCoordinate,
            radiusMiles: radius.rawValue,
            days: period.queryDays,
            limit: limit
        )
    }

    func requestCount(for status: PulseItem.Status) -> Int {
        requestStatusCounts?[status] ?? items.filter {
            $0.id.source == .serviceRequests311 && $0.status == status
        }.count
    }
    var lastUpdated: Date? {
        guard let data = defaults.data(forKey: cacheKey),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else { return nil }
        return entry.savedAt
    }
    var coordinateDescription: String {
        let latitudeDirection = searchCoordinate.latitude >= 0 ? "N" : "S"
        let longitudeDirection = searchCoordinate.longitude >= 0 ? "E" : "W"
        return "\(abs(searchCoordinate.latitude).formatted(.number.precision(.fractionLength(4))))° \(latitudeDirection), \(abs(searchCoordinate.longitude).formatted(.number.precision(.fractionLength(4))))° \(longitudeDirection)"
    }

    private var isFailure: Bool { if case .failed = state { true } else { false } }

    private func mergeCoverageItems(
        coordinate: PulseItem.Coordinate,
        radius: Radius,
        period: Period,
        limit: Int,
        requestSequence: Int,
        selectedRadius: Radius
    ) async throws {
        var loadedCount = 0
        var offset = 0
        var hasMore = true
        while hasMore, loadedCount < limit {
            try Task.checkCancellation()
            let page = try await repository.nearbyItems(
                coordinate: coordinate,
                radiusMiles: radius.rawValue,
                days: period.queryDays,
                offset: offset,
                limit: Self.mapPageSize
            )
            guard requestSequence == loadSequence,
                  coordinate == searchCoordinate,
                  selectedRadius == self.radius,
                  period == self.period else { throw CancellationError() }
            merge(page.items)
            loadedCount += page.items.count
            guard page.nextOffset > offset || !page.hasMore else { break }
            offset = page.nextOffset
            hasMore = page.hasMore
        }
    }

    private func merge(_ additionalItems: [PulseItem]) {
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for item in additionalItems { byID[item.id] = item }
        items = byID.values.sorted { $0.openedAt > $1.openedAt }
        if !items.isEmpty, state == .empty { state = .loaded }
    }

    private var cacheKey: String { "dcPulse.requestCache.v4" }

    private func restoreFreshCache(for coordinate: PulseItem.Coordinate, placeName: String) -> Bool {
        guard let data = defaults.data(forKey: cacheKey),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
              now().timeIntervalSince(entry.savedAt) < Self.cacheLifetime,
              entry.radius == radius, entry.period == period,
              requestStatusSummaryRepository == nil || entry.requestStatusCounts != nil,
              requestTrendSummaryRepository == nil || entry.requestTrendSnapshot != nil,
              abs(entry.coordinate.latitude - coordinate.latitude) < 0.0005,
              abs(entry.coordinate.longitude - coordinate.longitude) < 0.0005 else { return false }
        items = entry.items
        nextOffset = entry.nextOffset
        hasMore = entry.hasMore
        sourceWarnings = entry.warnings
        requestStatusCounts = entry.requestStatusCounts
        isRequestSummaryLoading = false
        requestTrendSnapshot = entry.requestTrendSnapshot
        isRequestInsightsLoading = false
        self.placeName = placeName == "Downtown DC" ? entry.placeName : placeName
        state = items.isEmpty ? .empty : .loaded
        return true
    }

    private func restoreMostRecentCache() -> Bool {
        guard let data = defaults.data(forKey: cacheKey),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
              now().timeIntervalSince(entry.savedAt) < Self.cacheLifetime,
              requestStatusSummaryRepository == nil || entry.requestStatusCounts != nil,
              requestTrendSummaryRepository == nil || entry.requestTrendSnapshot != nil else { return false }
        searchCoordinate = entry.coordinate
        radius = entry.radius
        period = entry.period
        placeName = entry.placeName
        items = entry.items
        nextOffset = entry.nextOffset
        hasMore = entry.hasMore
        sourceWarnings = entry.warnings
        requestStatusCounts = entry.requestStatusCounts
        isRequestSummaryLoading = false
        requestTrendSnapshot = entry.requestTrendSnapshot
        isRequestInsightsLoading = false
        state = items.isEmpty ? .empty : .loaded
        return true
    }

    private func saveCache() {
        let entry = CacheEntry(savedAt: now(), coordinate: searchCoordinate, radius: radius, period: period,
                               placeName: placeName, items: items, nextOffset: nextOffset, hasMore: hasMore,
                               warnings: sourceWarnings, requestStatusCounts: requestStatusCounts,
                               requestTrendSnapshot: requestTrendSnapshot)
        if let data = try? JSONEncoder().encode(entry) { defaults.set(data, forKey: cacheKey) }
    }

    private nonisolated static func loadStatusCounts(
        using repository: (any RequestStatusSummaryRepositoryProtocol)?,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async -> RequestStatusCounts? {
        guard let repository else { return nil }
        return try? await repository.statusCounts(
            coordinate: coordinate,
            radiusMiles: radiusMiles,
            days: days
        )
    }

    private nonisolated static func loadTrendSnapshot(
        using repository: (any RequestTrendSummaryRepositoryProtocol)?,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async -> RequestTrendSnapshot? {
        guard let repository else { return nil }
        return try? await repository.trendSnapshot(
            coordinate: coordinate,
            radiusMiles: radiusMiles,
            days: days
        )
    }
}

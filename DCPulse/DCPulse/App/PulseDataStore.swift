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
        let requestCategoryCounts: [String: Int]?
    }

    private struct MapCoverageResult {
        let warnings: [String]
        let recoveredSources: Set<PulseItem.Source>
    }

    private enum MapCoverageAttempt {
        case success(MapCoverageResult)
        case failed(String)
        case cancelled
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
        var compactLabel: String { "\(rawValue.formatted()) mi" }
        var distanceLabel: String { rawValue == 1 ? "1 mile" : "\(rawValue.formatted()) miles" }
        var radiusLabel: String { rawValue == 1 ? "1-mile radius" : "\(rawValue.formatted())-mile radius" }
        var accessibilityLabel: String {
            switch self {
            case .quarterMile: "quarter-mile radius"
            case .halfMile: "half-mile radius"
            case .oneMile: "one-mile radius"
            }
        }
    }

    enum State: Equatable { case idle, loading, loaded, empty, failed(String) }

    private let repository: any PulseRepositoryProtocol
    private let requestStatusSummaryRepository: (any RequestStatusSummaryRepositoryProtocol)?
    private let requestTrendSummaryRepository: (any RequestTrendSummaryRepositoryProtocol)?
    private let requestCategorySummaryRepository: (any RequestCategorySummaryRepositoryProtocol)?
    private let requestCategoryRepository: (any ServiceRequestCategoryRepositoryProtocol)?
    private let defaults: UserDefaults
    private let now: () -> Date
    private var loadSequence = 0
    private var requestCategorySequence = 0
    private var mapCoverageSequence = 0
    private var nextOffset = 0
    var items: [PulseItem] = []
    var state: State = .idle
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var isMapCoverageLoading = false
    private(set) var mapCoverageWarning: String?
    private(set) var loadMoreError: String?
    private(set) var sourceWarnings: [String] = []
    private(set) var requestStatusCounts: RequestStatusCounts?
    private(set) var isRequestSummaryLoading = false
    private(set) var requestTrendSnapshot: RequestTrendSnapshot?
    private(set) var isRequestInsightsLoading = false
    private(set) var selectedRequestStatus: PulseItem.Status?
    private(set) var isRequestCategorySummaryLoading = false
    private(set) var requestCategorySummaryUnavailable = false
    private var allRequestCategoryCounts: [String: Int]?
    private var requestCategoryCountsByStatus: [PulseItem.Status: [String: Int]] = [:]
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
        requestCategorySummaryRepository = ServiceRequest311CategorySummaryRepository()
        requestCategoryRepository = ServiceRequest311Repository()
        defaults = .standard
        now = { .now }
    }

    init(
        repository: any PulseRepositoryProtocol,
        requestStatusSummaryRepository: (any RequestStatusSummaryRepositoryProtocol)? = nil,
        requestTrendSummaryRepository: (any RequestTrendSummaryRepositoryProtocol)? = nil,
        requestCategorySummaryRepository: (any RequestCategorySummaryRepositoryProtocol)? = nil,
        requestCategoryRepository: (any ServiceRequestCategoryRepositoryProtocol)? = nil,
        defaults: UserDefaults? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        self.repository = repository
        self.requestStatusSummaryRepository = requestStatusSummaryRepository
        self.requestTrendSummaryRepository = requestTrendSummaryRepository
        self.requestCategorySummaryRepository = requestCategorySummaryRepository
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
        mapCoverageWarning = nil
        sourceWarnings = []
        requestStatusCounts = nil
        isRequestSummaryLoading = requestStatusSummaryRepository != nil
        requestTrendSnapshot = nil
        isRequestInsightsLoading = requestTrendSummaryRepository != nil
        requestCategorySequence += 1
        selectedRequestStatus = nil
        allRequestCategoryCounts = nil
        requestCategoryCountsByStatus = [:]
        requestCategorySummaryUnavailable = false
        isRequestCategorySummaryLoading = requestCategorySummaryRepository != nil
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
            async let categoryCountsRequest = Self.loadCategoryCounts(
                using: requestCategorySummaryRepository,
                status: nil,
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
            let categoryCounts = await categoryCountsRequest
            guard requestSequence == loadSequence else { return }
            if let categoryCounts {
                allRequestCategoryCounts = categoryCounts
            }
            requestCategorySummaryUnavailable = requestCategorySummaryRepository != nil && categoryCounts == nil
            isRequestCategorySummaryLoading = false
            saveCache()
        } catch is CancellationError {
            guard requestSequence == loadSequence else { return }
            isRequestSummaryLoading = false
            isRequestInsightsLoading = false
            isRequestCategorySummaryLoading = false
            state = .idle
        } catch {
            guard requestSequence == loadSequence else { return }
            isRequestSummaryLoading = false
            isRequestInsightsLoading = false
            isRequestCategorySummaryLoading = false
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
            clearRecoveredSourceWarnings(using: page.items)
            if !page.warnings.isEmpty {
                loadMoreError = "Some additional results could not be refreshed. Try again."
            }
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
    /// The selected radius then receives its own independent page budget; merged
    /// close-in items must never consume that wider-radius budget.
    func prepareMapResults() async {
        mapCoverageSequence += 1
        let coverageSequence = mapCoverageSequence
        let requestSequence = loadSequence
        let coordinate = searchCoordinate
        let selectedRadius = radius
        let selectedPeriod = period
        mapCoverageWarning = nil
        isMapCoverageLoading = true
        defer {
            if coverageSequence == mapCoverageSequence { isMapCoverageLoading = false }
        }

        if selectedRadius != .quarterMile {
            async let closeInAttempt = mapCoverageAttempt(
                coordinate: coordinate,
                radius: .quarterMile,
                period: selectedPeriod,
                requestSequence: requestSequence,
                coverageSequence: coverageSequence,
                selectedRadius: selectedRadius,
                failureMessage: "Some close-in map results could not be verified. Pull to refresh and try again."
            )
            async let selectedAttempt = mapCoverageAttempt(
                coordinate: coordinate,
                radius: selectedRadius,
                period: selectedPeriod,
                requestSequence: requestSequence,
                coverageSequence: coverageSequence,
                selectedRadius: selectedRadius,
                failureMessage: "Some map results could not be loaded. Pull to refresh and try again."
            )
            let attempts = await [closeInAttempt, selectedAttempt]
            guard finishMapCoverage(attempts, coverageSequence: coverageSequence) else { return }
        } else {
            let attempt = await mapCoverageAttempt(
                coordinate: coordinate,
                radius: selectedRadius,
                period: selectedPeriod,
                requestSequence: requestSequence,
                coverageSequence: coverageSequence,
                selectedRadius: selectedRadius,
                failureMessage: "Some map results could not be loaded. Pull to refresh and try again."
            )
            guard finishMapCoverage([attempt], coverageSequence: coverageSequence) else { return }
        }
        saveCache()
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
    var requestCategoryCounts: [String: Int] {
        if let selectedRequestStatus {
            return requestCategoryCountsByStatus[selectedRequestStatus] ?? [:]
        }
        return allRequestCategoryCounts ?? requestTrendSnapshot?.categoryCounts ?? [:]
    }
    var requestStatusCountsUnavailable: Bool {
        requestStatusSummaryRepository != nil && !isRequestSummaryLoading && requestStatusCounts == nil
    }
    var requestInsightsUnavailable: Bool {
        requestTrendSummaryRepository != nil && !isRequestInsightsLoading && requestTrendSnapshot == nil
    }

    func selectRequestStatus(_ status: PulseItem.Status?, force: Bool = false) async {
        guard status != .unknown, force || status != selectedRequestStatus else { return }
        selectedRequestStatus = status
        requestCategorySequence += 1
        let sequence = requestCategorySequence
        requestCategorySummaryUnavailable = false

        if (status.map { requestCategoryCountsByStatus[$0] != nil } ?? (allRequestCategoryCounts != nil)) ||
            (status == nil && requestCategorySummaryRepository == nil && requestTrendSnapshot != nil) {
            isRequestCategorySummaryLoading = false
            return
        }

        guard let requestCategorySummaryRepository else {
            isRequestCategorySummaryLoading = false
            requestCategorySummaryUnavailable = requestTrendSnapshot == nil
            return
        }
        isRequestCategorySummaryLoading = true
        let counts = await Self.loadCategoryCounts(
            using: requestCategorySummaryRepository,
            status: status,
            coordinate: searchCoordinate,
            radiusMiles: radius.rawValue,
            days: period.queryDays
        )
        guard sequence == requestCategorySequence, status == selectedRequestStatus else { return }
        if let counts {
            if let status { requestCategoryCountsByStatus[status] = counts }
            else { allRequestCategoryCounts = counts }
        }
        requestCategorySummaryUnavailable = counts == nil
        isRequestCategorySummaryLoading = false
    }

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
        coverageSequence: Int,
        selectedRadius: Radius
    ) async throws -> MapCoverageResult {
        var loadedCount = 0
        var offset = 0
        var hasMore = true
        var warnings: [String] = []
        var recoveredSources: Set<PulseItem.Source> = []
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
                  coverageSequence == mapCoverageSequence,
                  coordinate == searchCoordinate,
                  selectedRadius == self.radius,
                  period == self.period else { throw CancellationError() }
            merge(page.items)
            warnings += page.warnings
            recoveredSources.formUnion(page.items.map(\.id.source))
            loadedCount += page.items.count
            guard page.nextOffset > offset || !page.hasMore else { break }
            offset = page.nextOffset
            hasMore = page.hasMore
        }
        return MapCoverageResult(warnings: warnings, recoveredSources: recoveredSources)
    }

    private func mapCoverageAttempt(
        coordinate: PulseItem.Coordinate,
        radius: Radius,
        period: Period,
        requestSequence: Int,
        coverageSequence: Int,
        selectedRadius: Radius,
        failureMessage: String
    ) async -> MapCoverageAttempt {
        do {
            return .success(try await mergeCoverageItems(
                coordinate: coordinate,
                radius: radius,
                period: period,
                limit: Self.mapResultLimit,
                requestSequence: requestSequence,
                coverageSequence: coverageSequence,
                selectedRadius: selectedRadius
            ))
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(failureMessage)
        }
    }

    private func finishMapCoverage(
        _ attempts: [MapCoverageAttempt],
        coverageSequence: Int
    ) -> Bool {
        guard coverageSequence == mapCoverageSequence,
              !attempts.contains(where: { if case .cancelled = $0 { true } else { false } }) else { return false }
        let recoveredSources = attempts.reduce(into: Set<PulseItem.Source>()) { sources, attempt in
            if case .success(let result) = attempt {
                sources.formUnion(result.recoveredSources)
            }
        }
        clearRecoveredSourceWarnings(recoveredSources)

        let directFailures = attempts.compactMap { attempt -> String? in
            switch attempt {
            case .failed(let warning): warning
            case .success, .cancelled: nil
            }
        }
        let hasPartialSourceFailure = attempts.contains { attempt in
            if case .success(let result) = attempt { !result.warnings.isEmpty } else { false }
        }
        mapCoverageWarning = directFailures.first ?? (hasPartialSourceFailure
            ? "Some map results could not be refreshed. Try again."
            : nil)
        return true
    }

    private func clearRecoveredSourceWarnings(using items: [PulseItem]) {
        clearRecoveredSourceWarnings(Set(items.map(\.id.source)))
    }

    private func clearRecoveredSourceWarnings(_ recoveredSources: Set<PulseItem.Source>) {
        guard !recoveredSources.isEmpty else { return }
        sourceWarnings.removeAll { warning in
            recoveredSources.contains { source in
                warning.hasPrefix("\(availabilityName(for: source)) ")
            }
        }
    }

    private func availabilityName(for source: PulseItem.Source) -> String {
        switch source {
        case .serviceRequests311: "DC 311"
        case .buildingPermits2026: "Building Permits"
        case .ddotConstructionPermits2026: "DDOT Construction Permits"
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
              requestCategorySummaryRepository == nil || entry.requestCategoryCounts != nil,
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
        selectedRequestStatus = nil
        allRequestCategoryCounts = entry.requestCategoryCounts
        requestCategoryCountsByStatus = [:]
        isRequestCategorySummaryLoading = false
        requestCategorySummaryUnavailable = false
        self.placeName = placeName == "Downtown DC" ? entry.placeName : placeName
        state = items.isEmpty ? .empty : .loaded
        return true
    }

    private func restoreMostRecentCache() -> Bool {
        guard let data = defaults.data(forKey: cacheKey),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
              now().timeIntervalSince(entry.savedAt) < Self.cacheLifetime,
              requestStatusSummaryRepository == nil || entry.requestStatusCounts != nil,
              requestTrendSummaryRepository == nil || entry.requestTrendSnapshot != nil,
              requestCategorySummaryRepository == nil || entry.requestCategoryCounts != nil else { return false }
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
        selectedRequestStatus = nil
        allRequestCategoryCounts = entry.requestCategoryCounts
        requestCategoryCountsByStatus = [:]
        isRequestCategorySummaryLoading = false
        requestCategorySummaryUnavailable = false
        state = items.isEmpty ? .empty : .loaded
        return true
    }

    private func saveCache() {
        let entry = CacheEntry(savedAt: now(), coordinate: searchCoordinate, radius: radius, period: period,
                               placeName: placeName, items: items, nextOffset: nextOffset, hasMore: hasMore,
                               warnings: sourceWarnings, requestStatusCounts: requestStatusCounts,
                               requestTrendSnapshot: requestTrendSnapshot,
                               requestCategoryCounts: allRequestCategoryCounts)
        if let data = try? JSONEncoder().encode(entry) { defaults.set(data, forKey: cacheKey) }
    }

    private nonisolated static func loadStatusCounts(
        using repository: (any RequestStatusSummaryRepositoryProtocol)?,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async -> RequestStatusCounts? {
        guard let repository else { return nil }
        return await retrySummary {
            try await repository.statusCounts(
                coordinate: coordinate,
                radiusMiles: radiusMiles,
                days: days
            )
        }
    }

    private nonisolated static func loadTrendSnapshot(
        using repository: (any RequestTrendSummaryRepositoryProtocol)?,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async -> RequestTrendSnapshot? {
        guard let repository else { return nil }
        return await retrySummary {
            try await repository.trendSnapshot(
                coordinate: coordinate,
                radiusMiles: radiusMiles,
                days: days
            )
        }
    }

    private nonisolated static func loadCategoryCounts(
        using repository: (any RequestCategorySummaryRepositoryProtocol)?,
        status: PulseItem.Status?,
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async -> [String: Int]? {
        guard let repository else { return nil }
        return await retrySummary {
            try await repository.categoryCounts(
                status: status,
                coordinate: coordinate,
                radiusMiles: radiusMiles,
                days: days
            )
        }
    }

    private nonisolated static func retrySummary<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async -> Value? {
        for attempt in 0..<2 {
            do {
                return try await operation()
            } catch is CancellationError {
                return nil
            } catch {
                guard attempt == 0 else { return nil }
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return nil
                }
            }
        }
        return nil
    }
}

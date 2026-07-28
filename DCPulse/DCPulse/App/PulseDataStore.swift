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

    private struct CachePayload: Codable {
        static let currentVersion = 1

        let version: Int
        let entry: CacheEntry
    }

    private struct MapCoverageResult {
        let pass: MapCoveragePass
        let warnings: [String]
        let recoveredSources: Set<PulseItem.Source>
        let loadedCount: Int
    }

    private enum MapCoverageAttempt {
        case success(MapCoverageResult)
        case failed(MapCoverageIssue)
        case cancelled
    }

    enum MapCoveragePass: String, Sendable {
        case closeIn
        case selectedRadius

        func label(selectedRadius: Radius) -> String {
            switch self {
            case .closeIn: "Close-in (0.25-mile) coverage"
            case .selectedRadius: "Selected \(selectedRadius.rawValue.formatted())-mile coverage"
            }
        }
    }

    struct MapCoverageIssue: Identifiable, Equatable, Sendable {
        let pass: MapCoveragePass
        let message: String

        var id: String { "\(pass.rawValue):\(message)" }
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
    private let mapCacheStore: any MapCacheStoreProtocol
    private let now: () -> Date
    let mapPerformanceDiagnostics: any MapPerformanceDiagnosticsProtocol
    private var loadSequence = 0
    private var requestCategorySequence = 0
    private var mapCoverageSequence = 0
    private var nextOffset = 0
    var items: [PulseItem] = []
    var state: State = .idle
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var isMapCoverageLoading = false
    private(set) var mapCoverageLoadingDescription: String?
    private(set) var mapCoverageWarning: String?
    private(set) var mapCoverageIssues: [MapCoverageIssue] = []
    private(set) var loadMoreError: String?
    private(set) var sourceWarnings: [String] = []
    private(set) var requestStatusCounts: RequestStatusCounts?
    private(set) var isRequestSummaryLoading = false
    private(set) var requestTrendSnapshot: RequestTrendSnapshot?
    private(set) var isRequestInsightsLoading = false
    private(set) var selectedRequestStatus: PulseItem.Status?
    private(set) var isRequestCategorySummaryLoading = false
    private(set) var requestCategorySummaryUnavailable = false
    private(set) var lastUpdated: Date?
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
        mapCacheStore = FileBackedMapCacheStore()
        now = { .now }
        mapPerformanceDiagnostics = MapPerformanceDiagnostics.shared
    }

    init(
        repository: any PulseRepositoryProtocol,
        requestStatusSummaryRepository: (any RequestStatusSummaryRepositoryProtocol)? = nil,
        requestTrendSummaryRepository: (any RequestTrendSummaryRepositoryProtocol)? = nil,
        requestCategorySummaryRepository: (any RequestCategorySummaryRepositoryProtocol)? = nil,
        requestCategoryRepository: (any ServiceRequestCategoryRepositoryProtocol)? = nil,
        defaults: UserDefaults? = nil,
        mapCacheStore: (any MapCacheStoreProtocol)? = nil,
        now: @escaping () -> Date = { .now },
        mapPerformanceDiagnostics: any MapPerformanceDiagnosticsProtocol = MapPerformanceDiagnostics.shared
    ) {
        self.repository = repository
        self.requestStatusSummaryRepository = requestStatusSummaryRepository
        self.requestTrendSummaryRepository = requestTrendSummaryRepository
        self.requestCategorySummaryRepository = requestCategorySummaryRepository
        self.requestCategoryRepository = requestCategoryRepository
        self.defaults = defaults ?? UserDefaults(suiteName: "DCPulseTests.\(UUID().uuidString)")!
        self.mapCacheStore = mapCacheStore ?? TransientMapCacheStore()
        self.now = now
        self.mapPerformanceDiagnostics = mapPerformanceDiagnostics
    }

    func load(
        coordinate requestedCoordinate: PulseItem.Coordinate? = nil,
        placeName: String = "Downtown DC",
        force: Bool = false
    ) async {
        if requestedCoordinate == nil, !force, await restoreMostRecentCache() { return }
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
        mapCoverageIssues = []
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
        if !force, await restoreFreshCache(for: coordinate, placeName: placeName) { return }
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
            await saveCache()
            let counts = await countsRequest
            guard requestSequence == loadSequence else { return }
            requestStatusCounts = counts
            isRequestSummaryLoading = false
            await saveCache()
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
            await saveCache()
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
            if persistResult { await saveCache() }
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
        if loadedAdditionalItems { await saveCache() }
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
        mapCoverageIssues = []
        mapCoverageLoadingDescription = selectedRadius == .quarterMile
            ? "Loading 0.25-mile map coverage…"
            : "Loading close-in and \(selectedRadius.distanceLabel) map coverage…"
        let sessionContext = MapPerformanceContext(
            pass: selectedRadius == .quarterMile ? .selectedRadius : .closeInAndSelected,
            radiusMiles: selectedRadius.rawValue,
            limit: Self.mapResultLimit
        )
        let sessionInterval = mapPerformanceDiagnostics.begin(.coverageSession, context: sessionContext)
        var sessionOutcome = MapPerformanceOutcome.cancelled
        isMapCoverageLoading = true
        defer {
            mapPerformanceDiagnostics.end(
                sessionInterval,
                outcome: sessionOutcome,
                itemCount: items.count
            )
            if coverageSequence == mapCoverageSequence {
                isMapCoverageLoading = false
                mapCoverageLoadingDescription = nil
            }
        }

        if selectedRadius != .quarterMile {
            async let closeInAttempt = mapCoverageAttempt(
                pass: .closeIn,
                coordinate: coordinate,
                radius: .quarterMile,
                period: selectedPeriod,
                requestSequence: requestSequence,
                coverageSequence: coverageSequence,
                selectedRadius: selectedRadius
            )
            async let selectedAttempt = mapCoverageAttempt(
                pass: .selectedRadius,
                coordinate: coordinate,
                radius: selectedRadius,
                period: selectedPeriod,
                requestSequence: requestSequence,
                coverageSequence: coverageSequence,
                selectedRadius: selectedRadius
            )
            let attempts = await [closeInAttempt, selectedAttempt]
            guard finishMapCoverage(attempts, coverageSequence: coverageSequence) else { return }
        } else {
            let attempt = await mapCoverageAttempt(
                pass: .selectedRadius,
                coordinate: coordinate,
                radius: selectedRadius,
                period: selectedPeriod,
                requestSequence: requestSequence,
                coverageSequence: coverageSequence,
                selectedRadius: selectedRadius
            )
            guard finishMapCoverage([attempt], coverageSequence: coverageSequence) else { return }
        }
        sessionOutcome = mapCoverageIssues.isEmpty ? .succeeded : .partial
        mapPerformanceDiagnostics.milestone(
            .boundedCoverage,
            context: sessionContext,
            itemCount: items.count
        )
        await saveCache()
    }

    func retry() async {
        await load(coordinate: searchCoordinate, placeName: placeName, force: true)
        await prefetchSummary()
    }

    func retryMapCoverage() async {
        await prepareMapResults()
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
    var coordinateDescription: String {
        let latitudeDirection = searchCoordinate.latitude >= 0 ? "N" : "S"
        let longitudeDirection = searchCoordinate.longitude >= 0 ? "E" : "W"
        return "\(abs(searchCoordinate.latitude).formatted(.number.precision(.fractionLength(4))))° \(latitudeDirection), \(abs(searchCoordinate.longitude).formatted(.number.precision(.fractionLength(4))))° \(longitudeDirection)"
    }

    private var isFailure: Bool { if case .failed = state { true } else { false } }

    private func mergeCoverageItems(
        pass: MapCoveragePass,
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
            let mergeInterval = mapPerformanceDiagnostics.begin(
                .merge,
                context: MapPerformanceContext(
                    pass: performancePass(for: pass),
                    radiusMiles: radius.rawValue,
                    offset: offset,
                    limit: Self.mapPageSize
                )
            )
            merge(page.items)
            mapPerformanceDiagnostics.end(
                mergeInterval,
                outcome: .succeeded,
                itemCount: page.items.count
            )
            warnings += page.warnings
            recoveredSources.formUnion(page.items.map(\.id.source))
            loadedCount += page.items.count
            mapPerformanceDiagnostics.milestone(
                .coveragePage,
                context: MapPerformanceContext(
                    pass: performancePass(for: pass),
                    radiusMiles: radius.rawValue,
                    offset: offset,
                    limit: Self.mapPageSize
                ),
                itemCount: page.items.count
            )
            guard page.nextOffset > offset || !page.hasMore else { break }
            offset = page.nextOffset
            hasMore = page.hasMore
        }
        return MapCoverageResult(
            pass: pass,
            warnings: Array(Set(warnings)).sorted(),
            recoveredSources: recoveredSources,
            loadedCount: loadedCount
        )
    }

    private func mapCoverageAttempt(
        pass: MapCoveragePass,
        coordinate: PulseItem.Coordinate,
        radius: Radius,
        period: Period,
        requestSequence: Int,
        coverageSequence: Int,
        selectedRadius: Radius
    ) async -> MapCoverageAttempt {
        let context = MapPerformanceContext(
            pass: performancePass(for: pass),
            radiusMiles: radius.rawValue,
            limit: Self.mapResultLimit
        )
        let interval = mapPerformanceDiagnostics.begin(.coveragePass, context: context)
        do {
            let result = try await mergeCoverageItems(
                pass: pass,
                coordinate: coordinate,
                radius: radius,
                period: period,
                limit: Self.mapResultLimit,
                requestSequence: requestSequence,
                coverageSequence: coverageSequence,
                selectedRadius: selectedRadius
            )
            mapPerformanceDiagnostics.end(
                interval,
                outcome: result.warnings.isEmpty ? .succeeded : .partial,
                itemCount: result.loadedCount
            )
            mapPerformanceDiagnostics.milestone(
                pass == .closeIn ? .closeInCoverage : .selectedRadiusCoverage,
                context: context,
                itemCount: result.loadedCount
            )
            return .success(result)
        } catch is CancellationError {
            mapPerformanceDiagnostics.end(interval, outcome: .cancelled, itemCount: 0)
            return .cancelled
        } catch {
            mapPerformanceDiagnostics.end(interval, outcome: .failed, itemCount: 0)
            return .failed(MapCoverageIssue(
                pass: pass,
                message: "This coverage pass could not finish. Existing markers remain available."
            ))
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

        let directFailures = attempts.compactMap { attempt -> MapCoverageIssue? in
            switch attempt {
            case .failed(let issue): issue
            case .success, .cancelled: nil
            }
        }
        let partialSourceFailures = attempts.flatMap { attempt -> [MapCoverageIssue] in
            guard case .success(let result) = attempt else { return [] }
            return result.warnings.map { warning in
                MapCoverageIssue(
                    pass: result.pass,
                    message: "\(warning) Markers already on the map remain available."
                )
            }
        }
        mapCoverageIssues = Array(
            Dictionary(
                uniqueKeysWithValues: (directFailures + partialSourceFailures).map { ($0.id, $0) }
            ).values
        ).sorted {
            if $0.pass.rawValue == $1.pass.rawValue { return $0.message < $1.message }
            return $0.pass == .closeIn
        }
        mapCoverageWarning = mapCoverageIssues.isEmpty
            ? nil
            : "Map coverage is incomplete. Existing markers remain available."
        return true
    }

    private func clearRecoveredSourceWarnings(using items: [PulseItem]) {
        clearRecoveredSourceWarnings(Set(items.map(\.id.source)))
    }

    private func performancePass(for pass: MapCoveragePass) -> MapPerformancePass {
        pass == .closeIn ? .closeIn : .selectedRadius
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

    private func restoreFreshCache(
        for coordinate: PulseItem.Coordinate,
        placeName: String
    ) async -> Bool {
        let context = cacheContext(for: coordinate, radius: radius, period: period)
        if let record = await mapCacheStore.record(for: context),
           let entry = decodeCacheEntry(from: record),
           isFreshAndComplete(entry),
           abs(entry.coordinate.latitude - coordinate.latitude) < 0.0005,
           abs(entry.coordinate.longitude - coordinate.longitude) < 0.0005 {
            applyCacheEntry(entry, placeName: placeName, restoreCoordinate: false)
            return true
        }

        guard let entry = legacyCacheEntry(),
              isFreshAndComplete(entry),
              entry.radius == radius,
              entry.period == period,
              abs(entry.coordinate.latitude - coordinate.latitude) < 0.0005,
              abs(entry.coordinate.longitude - coordinate.longitude) < 0.0005 else {
            return false
        }
        applyCacheEntry(entry, placeName: placeName, restoreCoordinate: false)
        await migrateLegacyCache(entry)
        return true
    }

    private func restoreMostRecentCache() async -> Bool {
        if let record = await mapCacheStore.mostRecentRecord(),
           let entry = decodeCacheEntry(from: record),
           isFreshAndComplete(entry) {
            radius = entry.radius
            period = entry.period
            applyCacheEntry(entry, placeName: entry.placeName, restoreCoordinate: true)
            return true
        }

        guard let entry = legacyCacheEntry(),
              isFreshAndComplete(entry) else {
            return false
        }
        radius = entry.radius
        period = entry.period
        applyCacheEntry(entry, placeName: entry.placeName, restoreCoordinate: true)
        await migrateLegacyCache(entry)
        return true
    }

    private func applyCacheEntry(
        _ entry: CacheEntry,
        placeName: String,
        restoreCoordinate: Bool
    ) {
        if restoreCoordinate {
            searchCoordinate = entry.coordinate
        }
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
        lastUpdated = entry.savedAt
        state = items.isEmpty ? .empty : .loaded
    }

    private func legacyCacheEntry() -> CacheEntry? {
        guard let data = defaults.data(forKey: cacheKey),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else {
            return nil
        }
        return entry
    }

    private func isFreshAndComplete(_ entry: CacheEntry) -> Bool {
        let age = now().timeIntervalSince(entry.savedAt)
        return age >= 0 &&
        age < Self.cacheLifetime &&
        (requestStatusSummaryRepository == nil || entry.requestStatusCounts != nil) &&
        (requestTrendSummaryRepository == nil || entry.requestTrendSnapshot != nil) &&
        (requestCategorySummaryRepository == nil || entry.requestCategoryCounts != nil)
    }

    private func decodeCacheEntry(from record: MapCacheRecord) -> CacheEntry? {
        guard let payload = try? JSONDecoder().decode(CachePayload.self, from: record.payload),
              payload.version == CachePayload.currentVersion,
              payload.entry.savedAt == record.savedAt,
              payload.entry.items.count == record.itemCount,
              cacheContext(
                for: payload.entry.coordinate,
                radius: payload.entry.radius,
                period: payload.entry.period
              ) == record.context else {
            return nil
        }
        return payload.entry
    }

    private func cacheContext(
        for coordinate: PulseItem.Coordinate,
        radius: Radius,
        period: Period
    ) -> MapCacheContext {
        MapCacheContext(
            coordinate: coordinate,
            radiusMiles: radius.rawValue,
            periodDays: period.queryDays
        )
    }

    private func migrateLegacyCache(_ entry: CacheEntry) async {
        guard await persist(entry) != nil else { return }
        defaults.removeObject(forKey: cacheKey)
    }

    private func saveCache() async {
        let context = MapPerformanceContext(radiusMiles: radius.rawValue, limit: items.count)
        let interval = mapPerformanceDiagnostics.begin(.cacheEncoding, context: context)
        let entry = CacheEntry(savedAt: now(), coordinate: searchCoordinate, radius: radius, period: period,
                               placeName: placeName, items: items, nextOffset: nextOffset, hasMore: hasMore,
                               warnings: sourceWarnings, requestStatusCounts: requestStatusCounts,
                               requestTrendSnapshot: requestTrendSnapshot,
                               requestCategoryCounts: allRequestCategoryCounts)
        if let payloadSize = await persist(entry) {
            lastUpdated = entry.savedAt
            defaults.removeObject(forKey: cacheKey)
            mapPerformanceDiagnostics.end(interval, outcome: .succeeded, itemCount: payloadSize)
        } else {
            mapPerformanceDiagnostics.end(interval, outcome: .failed, itemCount: 0)
        }
    }

    private func persist(_ entry: CacheEntry) async -> Int? {
        let payload = CachePayload(version: CachePayload.currentVersion, entry: entry)
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        let record = MapCacheRecord(
            context: cacheContext(
                for: entry.coordinate,
                radius: entry.radius,
                period: entry.period
            ),
            savedAt: entry.savedAt,
            itemCount: entry.items.count,
            payload: data
        )
        do {
            try await mapCacheStore.save(record)
            return data.count
        } catch {
            return nil
        }
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

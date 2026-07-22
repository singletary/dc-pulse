import Foundation

struct NamedPulseRepository: Sendable {
    let name: String
    let repository: any PulseRepositoryProtocol
}

struct CombinedPulseRepository: PulseRepositoryProtocol, Sendable {
    let sources: [NamedPulseRepository]
    let sourceTimeout: Duration

    init(sources: [NamedPulseRepository], sourceTimeout: Duration = .seconds(4)) {
        self.sources = sources
        self.sourceTimeout = sourceTimeout
    }

    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) async throws -> PulsePage {
        guard !sources.isEmpty else { return PulsePage(items: [], nextOffset: offset, hasMore: false) }
        let sourceLimit = max(1, limit / sources.count)
        var pages: [PulsePage] = []
        var warnings: [String] = []

        await withTaskGroup(of: SourceResult.self) { group in
            for source in sources {
                group.addTask {
                    do {
                        let page = try await fetchPage(
                            from: source.repository,
                            coordinate: coordinate,
                            radiusMiles: radiusMiles,
                            days: days,
                            offset: offset,
                            limit: sourceLimit,
                            timeout: sourceTimeout
                        )
                        return SourceResult(page: page, warning: nil)
                    } catch is CancellationError {
                        return SourceResult(page: nil, warning: nil, wasCancelled: true)
                    } catch {
                        return SourceResult(page: nil, warning: "\(source.name) records are temporarily unavailable.")
                    }
                }
            }
            for await result in group {
                if result.wasCancelled { group.cancelAll() }
                if let page = result.page { pages.append(page) }
                if let warning = result.warning { warnings.append(warning) }
            }
        }

        if Task.isCancelled { throw CancellationError() }
        guard !pages.isEmpty else { throw CombinedRepositoryError.allSourcesUnavailable }
        return PulsePage(
            items: pages.flatMap(\.items).sorted { $0.openedAt > $1.openedAt },
            nextOffset: offset + sourceLimit,
            hasMore: pages.contains(where: \.hasMore),
            warnings: warnings.sorted()
        )
    }
}

private func fetchPage(
    from repository: any PulseRepositoryProtocol,
    coordinate: PulseItem.Coordinate,
    radiusMiles: Double,
    days: Int,
    offset: Int,
    limit: Int,
    timeout: Duration
) async throws -> PulsePage {
    try await withThrowingTaskGroup(of: PulsePage.self) { group in
        group.addTask {
            try await repository.nearbyItems(
                coordinate: coordinate,
                radiusMiles: radiusMiles,
                days: days,
                offset: offset,
                limit: limit
            )
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw SourceFetchError.timedOut
        }
        defer { group.cancelAll() }
        guard let page = try await group.next() else { throw CancellationError() }
        return page
    }
}

private enum SourceFetchError: Error { case timedOut }

private struct SourceResult: Sendable {
    let page: PulsePage?
    let warning: String?
    var wasCancelled = false
}

enum CombinedRepositoryError: LocalizedError {
    case allSourcesUnavailable

    var errorDescription: String? { "DC’s public data services are temporarily unavailable. Try again shortly." }
}

import Foundation

struct NamedPulseRepository: Sendable {
    let name: String
    let repository: any PulseRepositoryProtocol
}

struct CombinedPulseRepository: PulseRepositoryProtocol, Sendable {
    let sources: [NamedPulseRepository]

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
                        let page = try await source.repository.nearbyItems(
                            coordinate: coordinate, radiusMiles: radiusMiles, days: days,
                            offset: offset, limit: sourceLimit
                        )
                        return SourceResult(page: page, warning: nil)
                    } catch is CancellationError {
                        return SourceResult(page: nil, warning: nil, wasCancelled: true)
                    } catch {
                        return SourceResult(page: nil, warning: "\(source.name) is temporarily unavailable.")
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

private struct SourceResult: Sendable {
    let page: PulsePage?
    let warning: String?
    var wasCancelled = false
}

enum CombinedRepositoryError: LocalizedError {
    case allSourcesUnavailable

    var errorDescription: String? { "DC’s public data services are temporarily unavailable. Try again shortly." }
}

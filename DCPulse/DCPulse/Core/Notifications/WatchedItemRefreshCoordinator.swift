import Foundation

protocol WatchedItemRefreshRepositoryProtocol: Sendable {
    var source: PulseItem.Source { get }
    func items(withIdentifiers identifiers: [String]) async throws -> [PulseItem]
}

struct WatchedItemRefreshCoordinator: Sendable {
    struct StatusTransition: Equatable, Sendable {
        let previousStatus: PulseItem.Status
        let item: PulseItem
    }

    struct Result: Equatable, Sendable {
        let refreshedItems: [PulseItem]
        let transitions: [StatusTransition]
        let missingIDs: [PulseItem.ID]
        let failedSources: [PulseItem.Source]
    }

    private let repositories: [PulseItem.Source: any WatchedItemRefreshRepositoryProtocol]

    init(repositories: [any WatchedItemRefreshRepositoryProtocol]) {
        self.repositories = Dictionary(uniqueKeysWithValues: repositories.map { ($0.source, $0) })
    }

    static let live = WatchedItemRefreshCoordinator(repositories: [
        ServiceRequest311Repository(), BuildingPermitRepository(), DDOTConstructionPermitRepository()
    ])

    func refresh(_ watchedItems: [PulseItem]) async throws -> Result {
        let existing = Dictionary(uniqueKeysWithValues: watchedItems.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: watchedItems, by: { $0.id.source })
        var refreshed: [PulseItem] = []
        var failedSources: [PulseItem.Source] = []

        for source in grouped.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let repository = repositories[source] else {
                failedSources.append(source)
                continue
            }
            do {
                let identifiers = grouped[source, default: []].map(\.id.sourceIdentifier)
                refreshed.append(contentsOf: try await repository.items(withIdentifiers: identifiers))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedSources.append(source)
            }
        }

        let refreshedByID = Dictionary(uniqueKeysWithValues: refreshed.map { ($0.id, $0) })
        let transitions = refreshed.compactMap { item -> StatusTransition? in
            guard let prior = existing[item.id], prior.status != item.status else { return nil }
            return StatusTransition(previousStatus: prior.status, item: item)
        }
        let failedSet = Set(failedSources)
        let missing = watchedItems.compactMap { item in
            failedSet.contains(item.id.source) || refreshedByID[item.id] != nil ? nil : item.id
        }
        return Result(
            refreshedItems: refreshed.sorted { $0.openedAt > $1.openedAt },
            transitions: transitions,
            missingIDs: missing,
            failedSources: failedSources
        )
    }
}

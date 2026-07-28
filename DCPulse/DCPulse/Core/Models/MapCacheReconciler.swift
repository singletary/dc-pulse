import Foundation

enum MapSourceRefreshCoverage: Sendable {
    /// The source completed every page in the bounded refresh window. Cached
    /// records absent from this result may be removed for this source.
    case completeAuthoritative

    /// Some fresh records are usable, but pagination or another source boundary
    /// did not complete. Fresh records replace matching cached records only.
    case partial

    /// No fresh records from this source are trustworthy.
    case failed
}

struct MapSourceRefresh: Sendable {
    let source: PulseItem.Source
    let coverage: MapSourceRefreshCoverage
    let items: [PulseItem]

    init(
        source: PulseItem.Source,
        coverage: MapSourceRefreshCoverage,
        items: [PulseItem] = []
    ) {
        self.source = source
        self.coverage = coverage
        self.items = items
    }
}

struct MapCacheReconciliation: Equatable, Sendable {
    let items: [PulseItem]
    let refreshedSources: Set<PulseItem.Source>
    let retainedCachedSources: Set<PulseItem.Source>
}

/// A storage-independent prototype for stale-while-revalidate Map behavior.
///
/// Deletion is deliberately source-scoped and only permitted after the caller
/// proves that the bounded refresh completed. Partial and failed sources retain
/// their cached records so one ArcGIS outage cannot erase otherwise useful Map
/// context.
struct MapCacheReconciler: Sendable {
    func reconcile(
        cachedItems: [PulseItem],
        refreshes: [MapSourceRefresh]
    ) -> MapCacheReconciliation {
        var itemsByID: [PulseItem.ID: PulseItem] = [:]
        for item in cachedItems {
            itemsByID[item.id] = item
        }
        var refreshedSources: Set<PulseItem.Source> = []
        var retainedCachedSources: Set<PulseItem.Source> = []

        for refresh in refreshes {
            let validFreshItems = refresh.items.filter { $0.id.source == refresh.source }

            switch refresh.coverage {
            case .completeAuthoritative:
                itemsByID = itemsByID.filter { $0.key.source != refresh.source }
                refreshedSources.insert(refresh.source)
            case .partial:
                refreshedSources.insert(refresh.source)
                retainedCachedSources.insert(refresh.source)
            case .failed:
                retainedCachedSources.insert(refresh.source)
                continue
            }

            for item in validFreshItems {
                itemsByID[item.id] = item
            }
        }

        return MapCacheReconciliation(
            items: itemsByID.values.sorted { lhs, rhs in
                if lhs.openedAt == rhs.openedAt {
                    if lhs.id.source.rawValue == rhs.id.source.rawValue {
                        return lhs.id.sourceIdentifier < rhs.id.sourceIdentifier
                    }
                    return lhs.id.source.rawValue < rhs.id.source.rawValue
                }
                return lhs.openedAt > rhs.openedAt
            },
            refreshedSources: refreshedSources,
            retainedCachedSources: retainedCachedSources
        )
    }
}

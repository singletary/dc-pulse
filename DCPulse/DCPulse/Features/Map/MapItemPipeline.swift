import Foundation

struct MapItemPipeline: Sendable {
    enum Disposition: Equatable, Sendable {
        case notReceived
        case filteredBySource
        case filteredByStatus
        case filteredByCategory
        case missingCoordinate
        case annotation
    }

    struct Trace: Equatable, Sendable {
        let received: Int
        let unique: Int
        let filteredBySource: Int
        let filteredByStatus: Int
        let filteredByCategory: Int
        let missingCoordinate: Int
        let annotations: Int
    }

    let annotationItems: [PulseItem]
    let trace: Trace

    private let dispositions: [PulseItem.ID: Disposition]

    init(
        items: [PulseItem],
        selectedSources: Set<PulseItem.Source> = [],
        status: PulseItem.Status? = nil,
        category: String? = nil
    ) {
        var uniqueItems: [PulseItem.ID: PulseItem] = [:]
        for item in items { uniqueItems[item.id] = item }

        var dispositions: [PulseItem.ID: Disposition] = [:]
        var annotations: [PulseItem] = []
        var sourceCount = 0
        var statusCount = 0
        var categoryCount = 0
        var missingCoordinateCount = 0

        for item in uniqueItems.values {
            let disposition: Disposition
            if !selectedSources.isEmpty, !selectedSources.contains(item.id.source) {
                disposition = .filteredBySource
                sourceCount += 1
            } else if let status, item.status != status {
                disposition = .filteredByStatus
                statusCount += 1
            } else if let category, item.category != category {
                disposition = .filteredByCategory
                categoryCount += 1
            } else if item.coordinate == nil {
                disposition = .missingCoordinate
                missingCoordinateCount += 1
            } else {
                disposition = .annotation
                annotations.append(item)
            }
            dispositions[item.id] = disposition
        }

        annotationItems = annotations.sorted { $0.openedAt > $1.openedAt }
        trace = Trace(
            received: items.count,
            unique: uniqueItems.count,
            filteredBySource: sourceCount,
            filteredByStatus: statusCount,
            filteredByCategory: categoryCount,
            missingCoordinate: missingCoordinateCount,
            annotations: annotations.count
        )
        self.dispositions = dispositions
    }

    func disposition(of id: PulseItem.ID) -> Disposition {
        dispositions[id] ?? .notReceived
    }
}

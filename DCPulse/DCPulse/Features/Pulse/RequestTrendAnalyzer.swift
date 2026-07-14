import Foundation

struct RequestTrendSnapshot: Codable, Equatable, Sendable {
    var trends: [RequestTrendAnalyzer.Trend]
    var categories: [String]
}

protocol RequestTrendSummaryRepositoryProtocol: Sendable {
    func trendSnapshot(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async throws -> RequestTrendSnapshot
}

enum RequestTrendAnalyzer {
    struct Trend: Identifiable, Codable, Equatable, Sendable {
        enum Direction: String, Codable, Sendable { case increased, decreased, newlyObserved }

        var id: String { category }
        let category: String
        let currentCount: Int
        let previousCount: Int
        let percentChange: Int?
        let direction: Direction
    }

    static func snapshot(
        currentCounts: [String: Int],
        previousCounts: [String: Int],
        minimumCombinedCount: Int = 4
    ) -> RequestTrendSnapshot {
        let categories = Set(currentCounts.keys).union(previousCounts.keys).sorted()
        let trends = categories.compactMap { category -> Trend? in
            let current = currentCounts[category, default: 0]
            let previous = previousCounts[category, default: 0]
            guard current + previous >= minimumCombinedCount, current != previous else { return nil }

            if previous == 0 {
                return Trend(category: category, currentCount: current, previousCount: previous,
                             percentChange: nil, direction: .newlyObserved)
            }
            let percent = Int(((Double(current - previous) / Double(previous)) * 100).rounded())
            return Trend(category: category, currentCount: current, previousCount: previous,
                         percentChange: abs(percent), direction: percent > 0 ? .increased : .decreased)
        }
        .sorted {
            let leftDifference = abs($0.currentCount - $0.previousCount)
            let rightDifference = abs($1.currentCount - $1.previousCount)
            if leftDifference == rightDifference {
                return $0.currentCount + $0.previousCount > $1.currentCount + $1.previousCount
            }
            return leftDifference > rightDifference
        }
        return RequestTrendSnapshot(trends: trends, categories: categories)
    }
}

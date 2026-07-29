import Foundation

struct NeighborhoodInsightPresentation: Equatable {
    enum Style: Equatable {
        case increased
        case decreased
        case newlyObserved
        case leadingCategory
    }

    let category: String
    let title: String
    let detail: String
    let style: Style

    static func insights(
        trends: [RequestTrendAnalyzer.Trend],
        categoryCounts: [String: Int],
        windowDays: Int,
        status: PulseItem.Status?,
        limit: Int = 4
    ) -> [Self] {
        guard limit > 0 else { return [] }
        var presentations: [Self] = []
        var representedCategories: Set<String> = []

        // The trend query currently represents all request statuses. When a
        // lifecycle status is selected, use only the matching complete category
        // totals so the visible insight rows never imply a status-scoped trend.
        if status == nil {
            for trend in trends.prefix(limit) {
                presentations.append(Self(trend: trend, windowDays: windowDays))
                representedCategories.insert(trend.category)
            }
        }

        let categories = RequestCategorySummaryPresentation(counts: categoryCounts).categories
        for category in categories where presentations.count < limit {
            guard !representedCategories.contains(category.name) else { continue }
            presentations.append(Self(category: category, status: status))
            representedCategories.insert(category.name)
        }
        return presentations
    }

    private init(trend: RequestTrendAnalyzer.Trend, windowDays: Int) {
        category = trend.category
        style = switch trend.direction {
        case .increased: .increased
        case .decreased: .decreased
        case .newlyObserved: .newlyObserved
        }
        title = switch trend.direction {
        case .increased: "\(trend.category) increased nearby"
        case .decreased: "\(trend.category) decreased nearby"
        case .newlyObserved: "\(trend.category) newly appeared nearby"
        }
        detail = switch trend.direction {
        case .increased:
            "\(trend.currentCount) in the latest \(windowDays) days · ↑ \(trend.percentChange ?? 0)%"
        case .decreased:
            "\(trend.currentCount) in the latest \(windowDays) days · ↓ \(trend.percentChange ?? 0)%"
        case .newlyObserved:
            "\(trend.currentCount) in the latest \(windowDays) days · none in the prior period"
        }
    }

    private init(category: RequestCategorySummaryPresentation.Category, status: PulseItem.Status?) {
        self.category = category.name
        title = category.name
        let statusDescription = status.map { "\($0.displayName.lowercased()) " } ?? ""
        let requestNoun = category.count == 1 ? "request" : "requests"
        detail = "\(category.count) \(statusDescription)\(requestNoun) in the selected period"
        style = .leadingCategory
    }
}

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

    init?(
        trends: [RequestTrendAnalyzer.Trend],
        categoryCounts: [String: Int],
        windowDays: Int
    ) {
        if let trend = trends.first {
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
                "\(trend.currentCount) in the latest \(windowDays) days · up \(trend.percentChange ?? 0)%"
            case .decreased:
                "\(trend.currentCount) in the latest \(windowDays) days · down \(trend.percentChange ?? 0)%"
            case .newlyObserved:
                "\(trend.currentCount) in the latest \(windowDays) days · none in the prior period"
            }
            return
        }

        guard let leadingCategory = RequestCategorySummaryPresentation(counts: categoryCounts).categories.first else {
            return nil
        }
        category = leadingCategory.name
        title = "\(leadingCategory.name) leads nearby requests"
        detail = "\(leadingCategory.count) in the selected period"
        style = .leadingCategory
    }
}

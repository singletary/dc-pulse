import SwiftUI

struct NeighborhoodSummaryView: View {
    @Environment(PulseDataStore.self) private var store
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        List {
            Section("Category status") {
                Menu {
                    scopeButton(nil)
                    ForEach(PulseItem.Status.allCases.filter { $0 != .unknown }, id: \.self) {
                        scopeButton($0)
                    }
                } label: {
                    Label(
                        store.selectedRequestStatus?.displayName ?? "All statuses",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
                .accessibilityIdentifier("neighborhoodSummary.statusScope")
            }

            categorySection
            trendSection
        }
        .navigationTitle("Neighborhood Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var categorySection: some View {
        Section {
            if store.isRequestCategorySummaryLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Refreshing complete category totals…")
                        .foregroundStyle(.secondary)
                }
            } else if store.requestCategorySummaryUnavailable {
                Button {
                    Task {
                        await store.selectRequestStatus(
                            store.selectedRequestStatus,
                            force: true
                        )
                    }
                } label: {
                    Label("Retry category totals", systemImage: "arrow.clockwise.circle")
                }
                Text("Complete category totals are temporarily unavailable. Partial page counts are not substituted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if categoryPresentation.categories.isEmpty {
                ContentUnavailableView(
                    "No matching categories",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("No request categories match this status and search context.")
                )
            } else {
                ForEach(categoryPresentation.categories) { category in
                    Button { showOnMap(category.name) } label: {
                        HStack(spacing: 12) {
                            Text(PulseCategoryVisual.emoji(for: category.name))
                                .font(.title2)
                                .frame(width: 34, height: 34)
                                .background(.thinMaterial, in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                Text(categorySummary(category))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "map.fill")
                                .foregroundStyle(.indigo)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint("Shows this category on the map")
                }
            }
        } header: {
            Text("Request categories")
        } footer: {
            Text("Complete DC 311 category totals for the selected place, period, radius, and status.")
        }
    }

    @ViewBuilder private var trendSection: some View {
        if store.isRequestInsightsLoading {
            Section("Trends") {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Reading neighborhood patterns…")
                        .foregroundStyle(.secondary)
                }
            }
        } else if !store.requestTrends.isEmpty {
            Section {
                ForEach(store.requestTrends) { trend in
                    Button { showOnMap(trend.category) } label: {
                        HStack(spacing: 12) {
                            Text(PulseCategoryVisual.emoji(for: trend.category))
                                .font(.title2)
                                .frame(width: 32)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(trend.category)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(trendDescription(trend))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: trendIcon(trend))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(trendColor(trend))
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows this request type on the map")
                }
            } header: {
                Text("Trends")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trendContextDescription)
                    Text("Tap a trend to explore it on the map.")
                }
            }
        } else if store.requestInsightsUnavailable {
            Section("Trends") {
                Label(
                    "Trend summary temporarily unavailable",
                    systemImage: "chart.line.downtrend.xyaxis"
                )
                .foregroundStyle(.secondary)
            }
        } else {
            Section("Trends") {
                ContentUnavailableView(
                    "No meaningful trend yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Equal and low-sample comparisons are intentionally omitted.")
                )
            }
        }
    }

    private func scopeButton(_ status: PulseItem.Status?) -> some View {
        Button {
            Task { await store.selectRequestStatus(status) }
        } label: {
            if store.selectedRequestStatus == status {
                Label(status?.displayName ?? "All statuses", systemImage: "checkmark")
            } else {
                Text(status?.displayName ?? "All statuses")
            }
        }
    }

    private var categoryPresentation: RequestCategorySummaryPresentation {
        RequestCategorySummaryPresentation(counts: store.requestCategoryCounts)
    }

    private var trendWindowDays: Int {
        max(1, store.period.queryDays / 2)
    }

    private var trendContextDescription: String {
        guard let provenance = store.requestTrendSnapshot?.provenance else {
            return "Complete DC 311 totals from the latest \(trendWindowDays) days compared with the preceding \(trendWindowDays) days."
        }
        let current = Self.periodFormatter.string(from: provenance.currentPeriod.start)
            + "–" + Self.periodFormatter.string(from: provenance.currentPeriod.end)
        let previous = Self.periodFormatter.string(from: provenance.previousPeriod.start)
            + "–" + Self.periodFormatter.string(from: provenance.previousPeriod.end)
        let refreshed = Self.refreshFormatter.string(from: provenance.refreshedAt)
        let radius = provenance.radiusMiles == 1
            ? "1 mile"
            : "\(provenance.radiusMiles.formatted()) miles"
        return "DC 311 totals within \(radius) of \(store.placeName). \(current) compared with \(previous). Updated \(refreshed)."
    }

    private func categorySummary(
        _ category: RequestCategorySummaryPresentation.Category
    ) -> String {
        "\(category.count) request\(category.count == 1 ? "" : "s")"
    }

    private func trendDescription(_ trend: RequestTrendAnalyzer.Trend) -> String {
        switch trend.direction {
        case .increased:
            "\(trend.currentCount) in the latest \(trendWindowDays) days · up \(trend.percentChange ?? 0)%"
        case .decreased:
            "\(trend.currentCount) in the latest \(trendWindowDays) days · down \(trend.percentChange ?? 0)%"
        case .newlyObserved:
            "\(trend.currentCount) in the latest \(trendWindowDays) days · none in the prior period"
        }
    }

    private func trendIcon(_ trend: RequestTrendAnalyzer.Trend) -> String {
        switch trend.direction {
        case .increased: "arrow.up.right"
        case .decreased: "arrow.down.right"
        case .newlyObserved: "sparkles"
        }
    }

    private func trendColor(_ trend: RequestTrendAnalyzer.Trend) -> Color {
        switch trend.direction {
        case .increased: .orange
        case .decreased: .green
        case .newlyObserved: .indigo
        }
    }

    private func showOnMap(_ category: String) {
        navigation.requestedMapCategory = category
        navigation.requestedMapStatus = store.selectedRequestStatus
        navigation.selectedTab = .map
    }

    private static let periodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static let refreshFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

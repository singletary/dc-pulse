import SwiftData
import SwiftUI
import UIKit

struct PulseView: View {
    @Environment(PulseDataStore.self) private var store
    @Environment(LocationService.self) private var locationService
    @Environment(AppNavigation.self) private var navigation
    @Environment(HomeLocationStore.self) private var homeLocation
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var inAppNotifications: [InAppNotification]
    @State private var showingWardPicker = false
    @State private var showingAddressSearch = false
    @State private var showingSaveHome = false
    @State private var showingManualHome = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(locationDescription ?? store.placeName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Within \(store.radius.distanceLabel) · \(store.period.label)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(.indigo)
                    }
                    .accessibilityElement(children: .combine)

                    locationControl
                    locationGuidance
                    let areaActionLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                        : AnyLayout(HStackLayout(spacing: 18))
                    areaActionLayout {
                        Button("Choose Ward") { showingWardPicker = true }
                        Button("Search Address") { showingAddressSearch = true }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 6)
            }

            Section("Nearby snapshot") {
                let metricLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                metricLayout {
                    metricButton(.new, .blue)
                    metricButton(.active, .orange)
                    metricButton(.resolved, .green)
                }
                HStack {
                    Label(selectedStatusDescription, systemImage: store.selectedRequestStatus == nil ? "line.3.horizontal.decrease.circle" : "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(store.selectedRequestStatus == nil ? Color.secondary : Color.indigo)
                    Spacer()
                    if store.selectedRequestStatus != nil {
                        Button("Show All") { Task { await store.selectRequestStatus(nil) } }
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("pulse.status.all")
                    }
                }
                if let status = store.selectedRequestStatus {
                    NavigationLink(value: StatusItemsDestination(status: status)) {
                        Label("View \(status.displayName.lowercased()) requests", systemImage: "list.bullet")
                    }
                    .accessibilityIdentifier("pulse.status.viewList")
                }
                if store.requestStatusCountsUnavailable {
                    Button { Task { await store.retry() } } label: {
                        Label("Refresh complete request counts", systemImage: "arrow.clockwise.circle")
                    }
                    Text("Complete status totals are temporarily unavailable. DC Pulse won’t substitute partial page counts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if store.isRequestInsightsLoading || store.isRequestCategorySummaryLoading {
                Section("Neighborhood insight") {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Reading neighborhood patterns…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let neighborhoodInsight {
                Section("Neighborhood insight") {
                    Button {
                        showOnMap(neighborhoodInsight.category)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: insightIcon(neighborhoodInsight))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(insightColor(neighborhoodInsight))
                                .frame(width: 32)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(neighborhoodInsight.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(neighborhoodInsight.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "map.fill")
                                .foregroundStyle(.indigo)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows this request type on the map")
                }
            }

            Section("Noteworthy") {
                ForEach(store.sourceWarnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                requestContent
                if store.state == .loaded, !store.items.isEmpty {
                    Button {
                        navigation.selectedTab = .requests
                    } label: {
                        Label("See All Nearby Activity", systemImage: "list.bullet")
                    }
                    .accessibilityIdentifier("pulse.activity.all")
                }
            }

            Section {
                NavigationLink {
                    NeighborhoodSummaryView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Neighborhood Summary")
                                .font(.headline)
                            Text("Complete categories, trends, and data context")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundStyle(.indigo)
                    }
                }
                .accessibilityIdentifier("pulse.neighborhoodSummary")
            }

            Section("At Home") {
                if let address = homeLocation.address {
                    Label(address, systemImage: "house.fill").font(.subheadline)
                    if homeRequests.isEmpty {
                        ContentUnavailableView("Nothing at home right now", systemImage: "checkmark.circle",
                                               description: Text("No matching requests are in the current results."))
                    } else {
                        ForEach(homeRequests.prefix(3)) { item in
                            NavigationLink(value: item) { PulseItemRow(item: item) }
                        }
                    }
                } else {
                    Button { beginSavingHome() } label: {
                        Label("Save your home location", systemImage: "house")
                    }
                    Text("Track requests reported at your address.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

        }
        .navigationTitle("Near You")
        .navigationDestination(for: StatusItemsDestination.self) { StatusItemsView(status: $0.status) }
        .navigationDestination(for: PulseItem.self) { ItemDetailsView(item: $0) }
        .refreshable { await store.retry() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { NotificationsView() } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: unreadNotificationCount == 0 ? "bell" : "bell.fill")
                        if unreadNotificationCount > 0 {
                            Circle()
                                .fill(.red)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(.background, lineWidth: 1.5))
                                .offset(x: 3, y: -2)
                        }
                    }
                }
                .accessibilityLabel(notificationAccessibilityLabel)
                .accessibilityIdentifier("pulse.notifications")
            }
        }
        .sheet(isPresented: $showingWardPicker) { WardPickerView() }
        .sheet(isPresented: $showingAddressSearch) { AddressSearchView() }
        .sheet(isPresented: $showingManualHome) { HomeAddressEntryView() }
        .confirmationDialog("Save this as your home address?", isPresented: $showingSaveHome, titleVisibility: .visible) {
            Button("Save") { saveCurrentAsHome() }
            Button("Enter Address Manually") { showingManualHome = true }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Saving this as your home location lets you automatically track 311 requests at your address.\n\n\(currentAddress ?? "Current location")")
        }
    }

    private var unreadNotificationCount: Int {
        inAppNotifications.lazy.filter(\.isUnread).count
    }

    private var notificationAccessibilityLabel: String {
        unreadNotificationCount == 0
            ? "Notifications"
            : "Notifications, \(unreadNotificationCount) unread"
    }

    @ViewBuilder private var requestContent: some View {
        switch store.state {
        case .idle, .loading:
            HStack { Spacer(); ProgressView("Finding nearby requests…"); Spacer() }.padding()
        case .empty:
            ContentUnavailableView("No recent requests", systemImage: "checkmark.circle")
        case .failed(let message):
            ContentUnavailableView { Label("Couldn’t load requests", systemImage: "wifi.exclamationmark") }
            description: { Text(message) } actions: { Button("Try Again") { Task { await store.retry() } } }
        case .loaded:
            ForEach(noteworthyItems) { item in NavigationLink(value: item) { PulseItemRow(item: item) } }
        }
    }

    private var noteworthyItems: [PulseItem] {
        NoteworthyItemRanker.rank(store.items, homeCoordinate: homeLocation.coordinate)
            .prefix(3).map { $0 }
    }

    private var neighborhoodInsight: NeighborhoodInsightPresentation? {
        NeighborhoodInsightPresentation(
            trends: store.requestTrends,
            categoryCounts: store.requestCategoryCounts,
            windowDays: max(1, store.period.queryDays / 2)
        )
    }

    private func insightIcon(_ insight: NeighborhoodInsightPresentation) -> String {
        switch insight.style {
        case .increased: "arrow.up.right"
        case .decreased: "arrow.down.right"
        case .newlyObserved: "sparkles"
        case .leadingCategory: "chart.bar.fill"
        }
    }

    private func insightColor(_ insight: NeighborhoodInsightPresentation) -> Color {
        switch insight.style {
        case .increased: .orange
        case .decreased: .green
        case .newlyObserved, .leadingCategory: .indigo
        }
    }

    private var homeRequests: [PulseItem] {
        guard let home = homeLocation.address else { return [] }
        return store.items.filter { item in
            guard let address = item.address else { return false }
            return normalized(address) == normalized(home)
        }
    }

    private var locationDescription: String? {
        if store.placeName == "Current Location" { return locationService.locationLabel ?? "Near your current location" }
        return "Near \(store.placeName)"
    }

    private var currentAddress: String? {
        locationService.locationLabel?.replacingOccurrences(of: "Near ", with: "")
    }

    private var canSaveCurrentLocation: Bool {
        store.placeName == "Current Location" && locationService.coordinate != nil && currentAddress != nil
    }

    @ViewBuilder private var locationControl: some View {
        switch locationService.state {
        case .requestingPermission, .locating:
            Label("Finding your location…", systemImage: "location.fill").font(.subheadline).foregroundStyle(.secondary)
        case .located where store.placeName == "Current Location": EmptyView()
        case .denied:
            EmptyView()
        case .restricted:
            EmptyView()
        case .outsideDC:
            EmptyView()
        case .failed:
            EmptyView()
        default:
            Button("Use My Location") { locationService.requestCurrentLocation() }
        }
    }

    @ViewBuilder private var locationGuidance: some View {
        switch locationService.state {
        case .denied:
            guidanceCard(
                title: "Location is off",
                message: "You’re browsing Downtown DC. Turn on location for requests near you.",
                systemImage: "location.slash.fill",
                showsSettings: true
            )
        case .restricted:
            guidanceCard(
                title: "Location is unavailable",
                message: "You’re browsing Downtown DC. You can still choose a ward or search around an address.",
                systemImage: "location.slash.fill",
                showsRetry: false
            )
        case .failed:
            guidanceCard(
                title: "We couldn’t find your location",
                message: "You’re browsing Downtown DC for now. Try again or choose another area.",
                systemImage: "location.magnifyingglass"
            )
        case .outsideDC(let resolution):
            guidanceCard(
                title: "You appear to be outside DC",
                message: resolution.placeName == "Near the DC Border"
                    ? "Showing requests near the closest supported area inside DC."
                    : "You’re too far away for a nearby DC search, so we’re showing Downtown DC.",
                systemImage: "map.fill",
                showsRetry: false
            )
        default:
            EmptyView()
        }
    }

    private func guidanceCard(
        title: String,
        message: String,
        systemImage: String,
        showsSettings: Bool = false,
        showsRetry: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            if showsSettings || showsRetry {
                HStack(spacing: 14) {
                    if showsSettings,
                       let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Button("Open Settings") { openURL(settingsURL) }
                    } else if showsRetry {
                        Button("Try Again") { locationService.requestCurrentLocation() }
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private func metricButton(_ status: PulseItem.Status, _ color: Color) -> some View {
        let isSelected = store.selectedRequestStatus == status
        return Button { Task { await store.selectRequestStatus(status) } } label: {
            VStack(spacing: 3) {
                Group {
                    if store.isRequestSummaryLoading {
                        ProgressView().controlSize(.small)
                    } else if store.requestStatusCountsUnavailable {
                        Text("—")
                    } else {
                        Text("\(store.requestCount(for: status))")
                    }
                }
                .font(.title2.bold())
                .frame(height: 28)
                Text(status.displayName).font(.caption.weight(.medium))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(isSelected ? 0.18 : 0.09), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : .clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pulse.status.\(status.rawValue)")
        .accessibilityValue(store.requestStatusCountsUnavailable
                            ? "Complete count temporarily unavailable"
                            : "\(store.requestCount(for: status)), \(isSelected ? "selected" : "not selected")")
        .accessibilityHint(isSelected
                           ? "Selected. Use View requests to open the matching list."
                           : "Selects this status and refreshes category totals in Neighborhood Summary.")
    }

    private func showOnMap(_ category: String) {
        navigation.requestedMapCategory = category
        navigation.requestedMapStatus = store.selectedRequestStatus
        navigation.selectedTab = .map
    }

    private var selectedStatusDescription: String {
        guard let status = store.selectedRequestStatus else { return "All statuses" }
        return "\(status.displayName) selected"
    }

    private func beginSavingHome() {
        if canSaveCurrentLocation { showingSaveHome = true } else { showingManualHome = true }
    }

    private func saveCurrentAsHome() {
        guard let address = currentAddress, let coordinate = locationService.coordinate else { return }
        homeLocation.save(address: address, coordinate: coordinate)
    }

    private func normalized(_ value: String) -> String {
        String(value.lowercased().filter { $0.isLetter || $0.isNumber })
    }

}

struct RequestCategorySummaryPresentation {
    struct Category: Identifiable, Equatable {
        let name: String
        let count: Int

        var id: String { name }
    }

    static let collapsedCount = 3

    let categories: [Category]

    init(counts: [String: Int]) {
        categories = counts
            .map(Category.init(name:count:))
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }
    }

    var hasMoreCategories: Bool {
        categories.count > Self.collapsedCount
    }

    func visibleCategories(showingAll: Bool) -> [Category] {
        guard !showingAll else { return categories }
        return Array(categories.prefix(Self.collapsedCount))
    }

    func accessibilityValue(showingAll: Bool) -> String {
        let visibleCount = visibleCategories(showingAll: showingAll).count
        return "Showing \(visibleCount) of \(categories.count) categories"
    }
}

struct StatusItemsDestination: Identifiable, Hashable {
    let status: PulseItem.Status
    var id: PulseItem.Status { status }
}

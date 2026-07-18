import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct PulseView: View {
    @Environment(PulseDataStore.self) private var store
    @Environment(LocationService.self) private var locationService
    @Environment(AppNavigation.self) private var navigation
    @Environment(HomeLocationStore.self) private var homeLocation
    @Environment(\.openURL) private var openURL
    @Query private var inAppNotifications: [InAppNotification]
    @State private var showingWardPicker = false
    @State private var showingAddressSearch = false
    @State private var showingSaveHome = false
    @State private var showingManualHome = false
    @State private var selectedStatus: StatusItemsDestination?
    @State private var showingReport311 = false
    @State private var showingRestaurantHealth = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Within \(store.radius.distanceLabel)", systemImage: "location.circle.fill")
                        Text("· Within the last \(store.period.queryDays) days")
                    }
                    .font(.subheadline).foregroundStyle(.secondary)

                    HStack {
                        if let location = locationDescription {
                            Label(location, systemImage: "signpost.right")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isCurrentLocationSaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                        } else if canSaveCurrentLocation {
                            Button("I live here") { showingSaveHome = true }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    locationControl
                    locationGuidance
                }
                .padding(.vertical, 6)
            }

            Section("Requests nearby") {
                HStack {
                    metricButton(.new, .blue)
                    metricButton(.active, .orange)
                    metricButton(.resolved, .green)
                }
                if store.requestStatusCountsUnavailable || store.requestInsightsUnavailable {
                    Button { Task { await store.retry() } } label: {
                        Label("Refresh complete request counts", systemImage: "arrow.clockwise.circle")
                    }
                    Text("Some summary totals are temporarily unavailable. DC Pulse won’t substitute partial page counts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(topCategories, id: \.name) { category in
                    Button { showOnMap(category.name) } label: {
                        HStack(spacing: 12) {
                            Text(PulseCategoryVisual.emoji(for: category.name)).font(.title2)
                                .frame(width: 34, height: 34).background(.thinMaterial, in: Circle())
                            Text(categorySummary(name: category.name, count: category.count))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "map.fill").foregroundStyle(.indigo)
                        }
                    }
                    .accessibilityHint("Shows these updates on the map")
                }
            }

            if store.isRequestInsightsLoading {
                Section("What’s trending nearby") {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Reading neighborhood patterns…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else if !requestTrends.isEmpty {
                Section {
                    ForEach(requestTrends.prefix(3)) { trend in
                        Button { showOnMap(trend.category) } label: {
                            HStack(spacing: 12) {
                                Text(PulseCategoryVisual.emoji(for: trend.category))
                                    .font(.title2).frame(width: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(trend.category).font(.subheadline.weight(.semibold))
                                    Text(trendDescription(trend)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: trendIcon(trend))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(trendColor(trend))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows this request type on the map")
                    }
                } header: {
                    Text("What’s trending nearby")
                } footer: {
                    Text("Complete 311 totals from the latest \(trendWindowDays) days compared with the preceding \(trendWindowDays) days. Tap a trend to explore it on the map.")
                }
            } else if store.requestInsightsUnavailable {
                Section("What’s trending nearby") {
                    Label("Trend summary temporarily unavailable", systemImage: "chart.line.downtrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("My requests") {
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

            Section("Noteworthy changes") {
                ForEach(store.sourceWarnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                requestContent
            }

            Section("Explore another area") {
                Button { showingWardPicker = true } label: { Label("Browse by Ward", systemImage: "building.columns") }
                Button { showingAddressSearch = true } label: { Label("Search Around a DC Address", systemImage: "magnifyingglass") }
                Button { showingReport311 = true } label: {
                    Label("Report an Issue to 311", systemImage: "camera.viewfinder")
                }
                .accessibilityIdentifier("pulse.report311")
                Button { showingRestaurantHealth = true } label: {
                    Label("Restaurant Health Inspections", systemImage: "fork.knife")
                }
                .accessibilityIdentifier("pulse.restaurantHealth")
            }
        }
        .navigationTitle("Happening near you")
        .navigationDestination(item: $selectedStatus) { StatusItemsView(status: $0.status) }
        .navigationDestination(isPresented: $showingReport311) { Report311View() }
        .navigationDestination(isPresented: $showingRestaurantHealth) { RestaurantHealthView() }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await store.retry() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh nearby activity")
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
            .prefix(10).map { $0 }
    }

    private var requestTrends: [RequestTrendAnalyzer.Trend] {
        store.requestTrends
    }

    private var trendWindowDays: Int { max(1, store.period.queryDays / 2) }

    private func trendDescription(_ trend: RequestTrendAnalyzer.Trend) -> String {
        switch trend.direction {
        case .increased: "\(trend.currentCount) in the latest \(trendWindowDays) days · up \(trend.percentChange ?? 0)%"
        case .decreased: "\(trend.currentCount) in the latest \(trendWindowDays) days · down \(trend.percentChange ?? 0)%"
        case .newlyObserved: "\(trend.currentCount) in the latest \(trendWindowDays) days · none in the prior period"
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

    private var topCategories: [(name: String, count: Int)] {
        if store.requestInsightsUnavailable { return [] }
        if !store.requestCategoryCounts.isEmpty {
            return store.requestCategoryCounts
                .map { (name: $0.key, count: $0.value) }
                .sorted {
                    if $0.count == $1.count { return $0.name < $1.name }
                    return $0.count > $1.count
                }
                .prefix(3).map { $0 }
        }
        let requests = store.items.filter { $0.id.source == .serviceRequests311 }
        let groups: [String: [PulseItem]] = Dictionary(grouping: requests) { $0.category }
        let counts: [(name: String, count: Int)] = groups.map { (name: $0.key, count: $0.value.count) }
        let sorted = counts.sorted {
            if $0.count == $1.count { return $0.name < $1.name }
            return $0.count > $1.count
        }
        return Array(sorted.prefix(3))
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

    private var isCurrentLocationSaved: Bool {
        guard canSaveCurrentLocation,
              let saved = homeLocation.coordinate,
              let current = locationService.coordinate else { return false }
        let savedLocation = CLLocation(latitude: saved.latitude, longitude: saved.longitude)
        let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
        return savedLocation.distance(from: currentLocation) <= 50
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
            HStack { Button("Try Location Again") { locationService.requestCurrentLocation() }; Button("Choose Ward") { showingWardPicker = true } }
                .buttonStyle(.borderless)
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
                systemImage: "location.slash.fill"
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
                systemImage: "map.fill"
            )
        default:
            EmptyView()
        }
    }

    private func guidanceCard(
        title: String,
        message: String,
        systemImage: String,
        showsSettings: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                if showsSettings,
                   let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(settingsURL) }
                } else {
                    Button("Try Again") { locationService.requestCurrentLocation() }
                }
                Button("Choose Ward") { showingWardPicker = true }
                Button("Search Address") { showingAddressSearch = true }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private func metricButton(_ status: PulseItem.Status, _ color: Color) -> some View {
        Button { selectedStatus = StatusItemsDestination(status: status) } label: {
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
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pulse.status.\(status.rawValue)")
        .accessibilityValue(store.requestStatusCountsUnavailable
                            ? "Complete count temporarily unavailable"
                            : "\(store.requestCount(for: status))")
    }

    private func showOnMap(_ category: String) {
        navigation.requestedMapCategory = category
        navigation.selectedTab = .map
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

    private func categorySummary(name: String, count: Int) -> String {
        switch name {
        case "Building Permit": "\(count) building permit\(count == 1 ? "" : "s")"
        case "DDOT Construction Permit": "\(count) DDOT construction permit\(count == 1 ? "" : "s")"
        default: "\(count) \(name.lowercased()) request\(count == 1 ? "" : "s")"
        }
    }
}

struct StatusItemsDestination: Identifiable, Hashable {
    let status: PulseItem.Status
    var id: PulseItem.Status { status }
}

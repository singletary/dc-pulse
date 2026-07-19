import SwiftUI
import SwiftData
import UIKit

struct PlacesView: View {
    @Environment(PulseDataStore.self) private var store
    @Environment(LocationService.self) private var locationService
    @Environment(HomeLocationStore.self) private var homeLocation
    @Environment(AutoWatchSettingsStore.self) private var autoWatchSettings
    @Environment(WatchLifecycleSettingsStore.self) private var watchLifecycleSettings
    @Environment(AppNavigation.self) private var navigation
    @Environment(NotificationService.self) private var notificationService
    @Environment(WatchRefreshStatusStore.self) private var watchRefreshStatus
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchedPulseItem.watchedAt, order: .reverse) private var watchedItems: [WatchedPulseItem]
    @Query(sort: \FollowedPlace.followedAt, order: .reverse) private var followedPlaces: [FollowedPlace]
    @State private var showingWardPicker = false
    @State private var showingAddressSearch = false
    @State private var showingManualHome = false
    @State private var showingFollowSearch = false
    var body: some View {
        List {
            Section("Current search area") {
                Label {
                    VStack(alignment: .leading) {
                        Text(store.placeName).font(.headline)
                        Text("\(store.radius.compactLabel) · \(store.period.label)").font(.subheadline).foregroundStyle(.secondary)
                        if store.placeName == "Current Location", let label = locationService.locationLabel {
                            Text(label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } icon: { Image(systemName: store.placeName == "Current Location" ? "location.fill" : "building.columns.fill").foregroundStyle(.indigo) }
                if store.placeName != "Current Location" {
                    Button { locationService.requestCurrentLocation() } label: {
                        Label("Use My Location", systemImage: "location")
                    }
                }
                Button { showingWardPicker = true } label: {
                    Label("Browse by Ward", systemImage: "building.columns")
                }
                Button { showingAddressSearch = true } label: {
                    Label("Search Around a DC Address", systemImage: "magnifyingglass")
                }
                if let coordinate = locationService.coordinate,
                   let address = locationService.locationLabel?.replacingOccurrences(of: "Near ", with: "") {
                    Button {
                        homeLocation.save(address: address, coordinate: coordinate)
                    } label: {
                        Label(isCurrentLocationFollowed(address: address, coordinate: coordinate) ? "Following This Location" : "Follow This Location", systemImage: "house")
                    }
                    .disabled(isCurrentLocationFollowed(address: address, coordinate: coordinate))
                } else {
                    Button { showingManualHome = true } label: { Label("Follow a Home Address", systemImage: "house") }
                }
            }
            Section("Home") {
                if let address = homeLocation.address {
                    Label(address, systemImage: "house.fill")
                    Button { showingManualHome = true } label: {
                        Label("Change Home Address", systemImage: "pencil")
                    }
                    Toggle("Auto-watch nearby items", isOn: autoWatchBinding)
                    if autoWatchSettings.isEnabled {
                        Picker("Auto-watch distance", selection: autoWatchDistanceBinding) {
                            ForEach(AutoWatchSettingsStore.Distance.allCases) { distance in
                                Text(distance.label).tag(distance)
                            }
                        }
                        Text("Automatically watches new 311 requests and permits near home when DC Pulse refreshes.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Button { showingManualHome = true } label: {
                        Label("Add Home Address", systemImage: "house")
                    }
                }
            }
            Section {
                if followedPlaces.isEmpty {
                    Text("Save another DC address to return to its nearby map quickly.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(followedPlaces) { place in
                    Button {
                        load(place)
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(place.name).font(.headline)
                                    Text(place.address).font(.subheadline).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "mappin.and.ellipse").foregroundStyle(.indigo)
                            }
                            Spacer()
                            Image(systemName: "map").foregroundStyle(.indigo)
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions {
                        Button("Delete", role: .destructive) { modelContext.delete(place) }
                    }
                }
                Button { showingFollowSearch = true } label: {
                    Label("Follow another place", systemImage: "plus.circle")
                }
            } header: { Text("Saved places") }
            Section("Watched items") {
                if activeWatchedItems.isEmpty {
                    ContentUnavailableView(
                        "No watched items",
                        systemImage: "bell",
                        description: Text(archivedWatchedItems.isEmpty
                                          ? "Open a request or permit and choose Watch This Item."
                                          : "Restore an archived item or watch another request or permit.")
                    )
                } else {
                    ForEach(activeWatchedItems) { watched in
                        if let item = watched.item {
                            NavigationLink(value: item) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(item.category).font(.headline)
                                        Spacer()
                                        if watched.hasUnseenStatusChange {
                                            Label("Changed", systemImage: "sparkles")
                                                .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                                        }
                                    }
                                    Text(item.title).font(.subheadline).lineLimit(2)
                                    HStack(spacing: 8) {
                                        Label(item.status.displayName, systemImage: "bell.fill")
                                        if watched.origin == .automatic {
                                            Label("Near Home", systemImage: "house")
                                        }
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 3)
                            }
                            .accessibilityIdentifier("places.watch.active")
                            .swipeActions {
                                Button("Delete", role: .destructive) { modelContext.delete(watched) }
                                Button("Archive") { archive(watched) }
                                    .tint(.indigo)
                                    .accessibilityIdentifier("places.watch.archive")
                            }
                        }
                    }
                }
            }
            if !archivedWatchedItems.isEmpty {
                Section {
                    ForEach(archivedWatchedItems) { watched in
                        if let item = watched.item {
                            NavigationLink(value: item) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.category).font(.headline)
                                    Text(item.title).font(.subheadline).lineLimit(2)
                                    Label("Archived · \(item.status.displayName)", systemImage: "archivebox.fill")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 3)
                            }
                            .accessibilityIdentifier("places.watch.archived")
                            .swipeActions {
                                Button("Delete", role: .destructive) { modelContext.delete(watched) }
                                Button("Restore") { restore(watched) }
                                    .tint(.green)
                                    .accessibilityIdentifier("places.watch.restore")
                            }
                        }
                    }
                } header: {
                    Text("Archived")
                } footer: {
                    Text("Resolved watches you choose move here \(watchLifecycleSettings.explicitWatchGracePeriod.archiveDescription). Auto-watched items move here after 7 days. Swipe to restore one at any time.")
                }
            }
            Section("Alerts") {
                notificationControls
                if watchRefreshStatus.isRefreshing {
                    HStack { Spacer(); ProgressView("Checking watched items…"); Spacer() }
                } else {
                    Button { navigation.requestWatchRefresh() } label: {
                        Label("Check Watched Items Now", systemImage: "arrow.clockwise")
                    }
                    .disabled(activeWatchedItems.isEmpty)
                }
                if let lastSuccess = watchRefreshStatus.lastSuccess {
                    LabeledContent("Last watch check") {
                        Text(lastSuccess, format: .relative(presentation: .named))
                    }
                }
            }
            Section("Watch history") {
                Picker("Archive resolved watches", selection: explicitWatchGraceBinding) {
                    ForEach(WatchLifecycleSettingsStore.GracePeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .accessibilityIdentifier("places.watchArchivePreference")
                Text("This setting applies to items you choose to watch. Auto-watched items near Home archive after 7 days. Archived records remain available to restore.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Places")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { AboutView() } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("About DC Pulse")
                .accessibilityIdentifier("places.about")
            }
        }
        .navigationDestination(for: PulseItem.self) { item in
            ItemDetailsView(item: item)
                .onAppear { markSeen(item) }
        }
        .sheet(isPresented: $showingWardPicker) { WardPickerView() }
        .sheet(isPresented: $showingAddressSearch) { AddressSearchView() }
        .sheet(isPresented: $showingFollowSearch) { AddressSearchView(mode: .follow) }
        .sheet(isPresented: $showingManualHome) { HomeAddressEntryView() }
        .task { await notificationService.refreshAuthorizationState() }
    }

    private func markSeen(_ item: PulseItem) {
        let key = WatchedPulseItem.stableKey(for: item.id)
        watchedItems.first { $0.stableKey == key }?.markStatusChangeSeen()
        try? modelContext.save()
    }

    private var activeWatchedItems: [WatchedPulseItem] {
        watchedItems.filter { !$0.isArchived }
    }

    private var archivedWatchedItems: [WatchedPulseItem] {
        watchedItems.filter(\.isArchived)
    }

    private func archive(_ watched: WatchedPulseItem) {
        watched.archive()
        try? modelContext.save()
    }

    private func restore(_ watched: WatchedPulseItem) {
        watched.restore()
        try? modelContext.save()
    }

    private func load(_ place: FollowedPlace) {
        guard let coordinate = place.coordinate else { return }
        navigation.selectedTab = .map
        Task {
            await store.load(coordinate: coordinate, placeName: place.address, force: true)
            await store.prefetchSummary()
        }
    }

    private func isCurrentLocationFollowed(address: String, coordinate: PulseItem.Coordinate) -> Bool {
        if let homeCoordinate = homeLocation.coordinate,
           FollowedPlace.stableKey(for: homeCoordinate) == FollowedPlace.stableKey(for: coordinate) {
            return true
        }

        return followedPlaces.contains { place in
            FollowedPlace.matches(
                address: address,
                coordinate: coordinate,
                followedAddress: place.address,
                followedStableKey: place.stableKey
            )
        }
    }

    private var autoWatchBinding: Binding<Bool> {
        Binding(
            get: { autoWatchSettings.isEnabled },
            set: { enabled in
                autoWatchSettings.isEnabled = enabled
                guard enabled else { return }
                switch notificationService.authorizationState {
                case .notDetermined, .unknown:
                    Task {
                        if await notificationService.requestAuthorization() {
                            notificationService.newNearbyAlertsEnabled = true
                        }
                    }
                case .authorized:
                    notificationService.newNearbyAlertsEnabled = true
                case .denied:
                    break
                }
            }
        )
    }

    private var autoWatchDistanceBinding: Binding<AutoWatchSettingsStore.Distance> {
        Binding(
            get: { autoWatchSettings.distance },
            set: { autoWatchSettings.distance = $0 }
        )
    }

    private var explicitWatchGraceBinding: Binding<WatchLifecycleSettingsStore.GracePeriod> {
        Binding(
            get: { watchLifecycleSettings.explicitWatchGracePeriod },
            set: { watchLifecycleSettings.explicitWatchGracePeriod = $0 }
        )
    }

    @ViewBuilder private var notificationControls: some View {
        @Bindable var notifications = notificationService
        switch notificationService.authorizationState {
        case .unknown:
            HStack { Spacer(); ProgressView(); Spacer() }
        case .notDetermined:
            Button {
                Task {
                    if await notificationService.requestAuthorization() {
                        notificationService.statusChangeAlertsEnabled = true
                        notificationService.newNearbyAlertsEnabled = true
                    }
                }
            } label: {
                Label("Enable System Alerts", systemImage: "bell.badge")
            }
            Text("DC Pulse will ask before sending alerts and only notifies you after a data refresh finds a change.")
                .font(.caption).foregroundStyle(.secondary)
        case .denied:
            Label("Notifications are off in Settings", systemImage: "bell.slash")
                .foregroundStyle(.secondary)
            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                Label("Open Settings", systemImage: "gear")
            }
        case .authorized:
            Toggle("Watched status changes", isOn: $notifications.statusChangeAlertsEnabled)
            Toggle("New items near Home", isOn: $notifications.newNearbyAlertsEnabled)
                .disabled(!autoWatchSettings.isEnabled)
            if !autoWatchSettings.isEnabled {
                Text("Turn on Auto-watch nearby items to receive new-item alerts near Home.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("System alerts are sent only after DC Pulse refreshes and finds matching activity. Delivery is not immediate.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

import SwiftUI
import Observation
import SwiftData

enum AppTab: Hashable { case pulse, map, requests, places }

@MainActor @Observable
final class AppNavigation {
    var selectedTab: AppTab = .pulse
    var requestedMapCategory: String?
    var watchRefreshRequestID = 0

    func requestWatchRefresh() { watchRefreshRequestID += 1 }
}

struct AppRootView: View {
    @State private var store = PulseDataStore()
    @State private var locationService = LocationService()
    @State private var navigation = AppNavigation()
    @State private var homeLocation = HomeLocationStore()
    @State private var autoWatchSettings = AutoWatchSettingsStore()
    @State private var notificationService = NotificationService()
    @State private var watchRefreshStatus = WatchRefreshStatusStore()
    @State private var notificationPresentation: NotificationPresentation?
    @Environment(\.modelContext) private var modelContext
    @Query private var watchedItems: [WatchedPulseItem]
    @Query private var observations: [PulseObservationRecord]

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            Tab("Near You", systemImage: "waveform.path.ecg", value: .pulse) { NavigationStack { PulseView() } }
            Tab("Map", systemImage: "map", value: .map) { NavigationStack { PulseMapView() } }
            Tab("Requests", systemImage: "clock.arrow.circlepath", value: .requests) { NavigationStack { ActivityView() } }
            Tab("Places", systemImage: "bookmark", value: .places) { NavigationStack { PlacesView() } }
        }
        .tint(.indigo)
        .environment(store)
        .environment(locationService)
        .environment(navigation)
        .environment(homeLocation)
        .environment(autoWatchSettings)
        .environment(notificationService)
        .environment(watchRefreshStatus)
        .task {
            await notificationService.refreshAuthorizationState()
            locationService.requestCurrentLocation()
            await store.load()
            await refreshWatchedItems()
        }
        .onChange(of: locationService.updateSequence) { _, _ in
            guard let coordinate = locationService.coordinate else { return }
            Task {
                await store.load(coordinate: coordinate, placeName: "Current Location")
            }
        }
        .onChange(of: store.items) { _, items in
            synchronizeWatches(with: items)
        }
        .onChange(of: navigation.watchRefreshRequestID) { _, _ in
            Task { await refreshWatchedItems() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWatchedPulseItem)) { notification in
            guard let userInfo = notification.userInfo,
                  let destination = NotificationDestination(userInfo: userInfo) else { return }
            notificationPresentation = NotificationPresentation(
                itemID: destination.itemID,
                item: watchedItems.compactMap(\.item).first { $0.id == destination.itemID }
            )
        }
        .sheet(item: $notificationPresentation) { destination in
            NavigationStack {
                if let item = destination.item {
                    ItemDetailsView(item: item)
                } else {
                    ContentUnavailableView(
                        "Watched item unavailable",
                        systemImage: "bell.slash",
                        description: Text("DC Pulse no longer has a saved copy of this record.")
                    )
                    .navigationTitle("Notification")
                }
            }
        }
    }

    private func synchronizeWatches(with items: [PulseItem]) {
        let currentItems = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for watchedItem in watchedItems {
            guard let watchedID = watchedItem.item?.id,
                  let current = currentItems[watchedID] else { continue }
            let previousStatus = PulseItem.Status(rawValue: watchedItem.statusRawValue)
            watchedItem.update(from: current)
            if let previousStatus, previousStatus != current.status {
                Task {
                    await notificationService.notifyStatusChange(
                        item: current,
                        previousStatus: previousStatus
                    )
                }
            }
        }
        addAutomaticWatches(from: items)
        recordObservations(from: items)
        try? modelContext.save()
    }

    private func recordObservations(from items: [PulseItem]) {
        let existing = Dictionary(uniqueKeysWithValues: observations.map { ($0.stableKey, $0) })
        for item in items {
            let key = WatchedPulseItem.stableKey(for: item.id)
            if let observation = existing[key] {
                observation.update(from: item)
            } else {
                modelContext.insert(PulseObservationRecord(item: item))
            }
        }
    }

    private func addAutomaticWatches(from items: [PulseItem]) {
        guard autoWatchSettings.isEnabled, let home = homeLocation.coordinate else { return }
        var watchedKeys = Set(watchedItems.map(\.stableKey))

        for item in AutoWatchPolicy.candidates(
            from: items,
            home: home,
            distanceMiles: autoWatchSettings.distance.rawValue,
            excluding: watchedKeys
        ) {
            let key = WatchedPulseItem.stableKey(for: item.id)
            modelContext.insert(WatchedPulseItem(item: item))
            watchedKeys.insert(key)
        }
    }

    private func refreshWatchedItems() async {
        let snapshots = watchedItems.compactMap(\.item)
        guard !snapshots.isEmpty, !watchRefreshStatus.isRefreshing else { return }
        watchRefreshStatus.begin()
        do {
            let result = try await WatchedItemRefreshCoordinator.live.refresh(snapshots)
            let transitions = Dictionary(uniqueKeysWithValues: result.transitions.map { ($0.item.id, $0) })
            for item in result.refreshedItems {
                guard let watched = watchedItems.first(where: { $0.stableKey == WatchedPulseItem.stableKey(for: item.id) }) else {
                    continue
                }
                watched.update(from: item)
                if let transition = transitions[item.id] {
                    await notificationService.notifyStatusChange(
                        item: transition.item,
                        previousStatus: transition.previousStatus
                    )
                }
            }
            try? modelContext.save()
            watchRefreshStatus.complete(success: result.failedSources.isEmpty)
        } catch is CancellationError {
            watchRefreshStatus.complete(success: false)
        } catch {
            watchRefreshStatus.complete(success: false)
        }
    }
}

private struct NotificationPresentation: Identifiable {
    let itemID: PulseItem.ID
    let item: PulseItem?
    var id: PulseItem.ID { itemID }
}

#Preview {
    AppRootView()
        .modelContainer(
            for: [WatchedPulseItem.self, FollowedPlace.self, PulseObservationRecord.self],
            inMemory: true
        )
}

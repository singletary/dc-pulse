import SwiftUI
import SwiftData

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @Environment(PulseDataStore.self) private var store
    @Environment(HomeLocationStore.self) private var homeLocation
    @Query(sort: \FollowedPlace.followedAt, order: .reverse) private var followedPlaces: [FollowedPlace]
    @State private var sourceFilter: PulseItem.Source?
    var body: some View {
        List {
            Section("Browsing") {
                Menu {
                    if let homeCoordinate = homeLocation.coordinate,
                       let homeAddress = homeLocation.address {
                        locationButton(name: "Home", address: homeAddress, coordinate: homeCoordinate, icon: "house.fill")
                    }
                    ForEach(uniqueFollowedPlaces) { place in
                        if let coordinate = place.coordinate {
                            locationButton(name: place.name, address: place.address, coordinate: coordinate, icon: "mappin.and.ellipse")
                        }
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.placeName).font(.headline)
                            Text("Within \(store.radius.label) · \(store.period.label)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "location.magnifyingglass").foregroundStyle(.indigo)
                    }
                }
                .accessibilityIdentifier("requests.locationPicker")
                .disabled(homeLocation.coordinate == nil && followedPlaces.isEmpty)
                if homeLocation.coordinate == nil && followedPlaces.isEmpty {
                    Text("Follow a location in Places to browse its requests here.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Nearby requests and permits") {
                ForEach(sortedItems) { item in NavigationLink(value: item) { PulseItemRow(item: item) } }
                pagingFooter
            }
        }
        .navigationTitle("Requests")
        .toolbar {
            Menu {
                Picker("Sort requests", selection: $viewModel.sort) {
                    ForEach(ActivityViewModel.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Divider()
                Button { sourceFilter = nil } label: {
                    if sourceFilter == nil { Label("All data", systemImage: "checkmark") } else { Text("All data") }
                }
                ForEach(availableSources, id: \.self) { source in
                    Button { sourceFilter = source } label: {
                        if sourceFilter == source { Label(source.displayName, systemImage: "checkmark") }
                        else { Text(source.displayName) }
                    }
                }
            } label: {
                Label(viewModel.sort.rawValue, systemImage: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityHint("Changes sorting or filters by data source")
        }
        .navigationDestination(for: PulseItem.self) { ItemDetailsView(item: $0) }
        .overlay {
            if store.isLoading {
                SearchLoadingOverlay(placeName: store.placeName, radius: store.radius, period: store.period)
            }
        }
    }

    @ViewBuilder private var pagingFooter: some View {
        if store.isLoadingMore {
            HStack { Spacer(); ProgressView("Loading more…"); Spacer() }
        } else if let message = store.loadMoreError {
            Button { Task { await store.loadMore() } } label: {
                Label("Try loading more", systemImage: "arrow.clockwise")
            }
            .accessibilityHint(message)
        } else if store.hasMore {
            HStack { Spacer(); ProgressView("Loading more…"); Spacer() }
                .task { await store.loadMore() }
        }
    }

    private var sortedItems: [PulseItem] {
        store.items
            .filter { sourceFilter == nil || $0.id.source == sourceFilter }
            .sorted { viewModel.sort == .newest ? $0.openedAt > $1.openedAt : $0.openedAt < $1.openedAt }
    }

    private var availableSources: [PulseItem.Source] {
        Array(Set(store.items.map(\.id.source))).sorted { $0.displayName < $1.displayName }
    }

    private var uniqueFollowedPlaces: [FollowedPlace] {
        guard let homeCoordinate = homeLocation.coordinate else { return followedPlaces }
        let homeKey = FollowedPlace.stableKey(for: homeCoordinate)
        return followedPlaces.filter { $0.stableKey != homeKey }
    }

    private func locationButton(
        name: String,
        address: String,
        coordinate: PulseItem.Coordinate,
        icon: String
    ) -> some View {
        Button {
            browse(name: name, address: address, coordinate: coordinate)
        } label: {
            if FollowedPlace.stableKey(for: coordinate) == FollowedPlace.stableKey(for: store.searchCoordinate) {
                Label(address, systemImage: "checkmark")
            } else {
                Label(name == address ? address : "\(name): \(address)", systemImage: icon)
            }
        }
    }

    private func browse(name: String, address: String, coordinate: PulseItem.Coordinate) {
        sourceFilter = nil
        Task {
            await store.load(coordinate: coordinate, placeName: name == "Home" ? "Home · \(address)" : address)
            await store.prefetchSummary()
        }
    }
}

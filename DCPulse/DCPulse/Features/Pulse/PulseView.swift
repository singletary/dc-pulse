import SwiftUI

struct PulseView: View {
    @State private var viewModel = PulseViewModel()
    @Environment(PulseDataStore.self) private var store
    @Environment(LocationService.self) private var locationService
    @State private var showingWardPicker = false
    @State private var didOfferWardFallback = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Near \(store.placeName)").font(.title2.bold())
                    Label("Within \(store.radius.label) · Last \(viewModel.periodDays) days", systemImage: "location.circle")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(store.coordinateDescription)
                        .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                    if store.placeName == "Current Location", let label = locationService.locationLabel {
                        Label(label, systemImage: "signpost.right").font(.caption).foregroundStyle(.secondary)
                    }
                    locationControl
                }.padding(.vertical, 8)
            }
            Section("At a glance") {
                HStack {
                    metric(store.items.filter { $0.status == .new }.count, "New", .blue)
                    metric(store.items.filter { $0.status == .active }.count, "Active", .orange)
                    metric(store.items.filter { $0.status == .resolved }.count, "Resolved", .green)
                }
            }
            Section("Search radius") {
                Picker("Radius", selection: radiusBinding) {
                    ForEach(PulseDataStore.Radius.allCases) { radius in Text(radius.label).tag(radius) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Button { showingWardPicker = true } label: { Label("Browse by Ward", systemImage: "building.columns") }
            }
            Section("Noteworthy changes") {
                switch store.state {
                case .idle, .loading:
                    HStack { Spacer(); ProgressView("Loading nearby 311 activity…"); Spacer() }.padding()
                case .empty:
                    ContentUnavailableView("No recent 311 activity", systemImage: "checkmark.circle", description: Text("No requests were found within \(store.radius.label) in the last 30 days."))
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn’t load activity", systemImage: "wifi.exclamationmark")
                    } description: { Text(message) } actions: { Button("Try Again") { Task { await store.retry() } } }
                case .loaded:
                    ForEach(store.items) { item in NavigationLink(value: item) { PulseItemRow(item: item) } }
                    pagingFooter
                }
            }
        }
        .navigationTitle("Pulse")
        .navigationDestination(for: PulseItem.self) { ItemDetailsView(item: $0) }
        .overlay { if store.isLoading { SearchLoadingOverlay(placeName: store.placeName, radius: store.radius) } }
        .sheet(isPresented: $showingWardPicker) { WardPickerView() }
        .onChange(of: locationService.state) { _, state in
            switch state {
            case .denied, .restricted, .failed: offerWardFallback()
            default: break
            }
        }
        .onChange(of: store.state) { _, state in
            if state == .empty, store.placeName == "Current Location" { offerWardFallback() }
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

    private var radiusBinding: Binding<PulseDataStore.Radius> {
        Binding(get: { store.radius }, set: { radius in Task { await store.selectRadius(radius) } })
    }

    private func offerWardFallback() {
        guard !didOfferWardFallback else { return }
        didOfferWardFallback = true
        showingWardPicker = true
    }

    @ViewBuilder private var locationControl: some View {
        switch locationService.state {
        case .requestingPermission, .locating:
            Label("Finding your location…", systemImage: "location.fill").font(.subheadline).foregroundStyle(.secondary)
        case .located where store.placeName == "Current Location":
            Label("Using your current location", systemImage: "location.fill").font(.subheadline).foregroundStyle(.indigo)
        case .denied:
            VStack(alignment: .leading, spacing: 4) {
                Label("Location access is off", systemImage: "location.slash")
                Text("Enable location in Settings, or keep using Downtown DC.").font(.caption).foregroundStyle(.secondary)
            }
        case .restricted:
            Text("Location access is restricted. Using Downtown DC.").font(.caption).foregroundStyle(.secondary)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message).font(.caption).foregroundStyle(.secondary)
                Button("Try Location Again") { locationService.requestCurrentLocation() }.buttonStyle(.borderless)
            }
        default:
            Button { locationService.requestCurrentLocation() } label: { Label("Use My Location", systemImage: "location") }
                .buttonStyle(.borderless)
        }
    }

    private func metric(_ value: Int, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 4) { Text("\(value)").font(.title.bold()).foregroundStyle(color); Text(title).font(.caption) }
            .frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}

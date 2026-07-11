import SwiftUI

struct PulseView: View {
    @State private var viewModel = PulseViewModel()
    @Environment(PulseDataStore.self) private var store
    @Environment(LocationService.self) private var locationService

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Near \(store.placeName)").font(.title2.bold())
                    Label("Within \(viewModel.radiusMiles) mile · Last \(viewModel.periodDays) days", systemImage: "location.circle")
                        .font(.subheadline).foregroundStyle(.secondary)
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
            Section("Noteworthy changes") {
                switch store.state {
                case .idle, .loading:
                    HStack { Spacer(); ProgressView("Loading nearby 311 activity…"); Spacer() }.padding()
                case .empty:
                    ContentUnavailableView("No recent 311 activity", systemImage: "checkmark.circle", description: Text("No requests were found within one mile in the last 30 days."))
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn’t load activity", systemImage: "wifi.exclamationmark")
                    } description: { Text(message) } actions: { Button("Try Again") { Task { await store.retry() } } }
                case .loaded:
                    ForEach(store.items) { item in NavigationLink(value: item) { PulseItemRow(item: item) } }
                }
            }
        }
        .navigationTitle("Pulse")
        .navigationDestination(for: PulseItem.self) { ItemDetailsView(item: $0) }
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

import SwiftUI

struct PulseView: View {
    @State private var viewModel = PulseViewModel()
    @Environment(PulseDataStore.self) private var store

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Near Downtown DC").font(.title2.bold())
                    Label("Within \(viewModel.radiusMiles) mile · Last \(viewModel.periodDays) days", systemImage: "location.circle")
                        .font(.subheadline).foregroundStyle(.secondary)
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

    private func metric(_ value: Int, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 4) { Text("\(value)").font(.title.bold()).foregroundStyle(color); Text(title).font(.caption) }
            .frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}

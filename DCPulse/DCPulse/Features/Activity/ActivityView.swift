import SwiftUI

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @Environment(PulseDataStore.self) private var store
    var body: some View {
        List {
            Section { Label("Within 1 mile · Last 30 days", systemImage: "line.3.horizontal.decrease.circle").foregroundStyle(.secondary) }
            Section("Timeline") {
                ForEach(sortedItems) { item in NavigationLink(value: item) { PulseItemRow(item: item) } }
            }
        }
        .navigationTitle("Activity")
        .toolbar { Picker("Sort", selection: $viewModel.sort) { ForEach(ActivityViewModel.Sort.allCases, id: \.self) { Text($0.rawValue) } } }
        .navigationDestination(for: PulseItem.self) { ItemDetailsView(item: $0) }
    }

    private var sortedItems: [PulseItem] {
        store.items.sorted { viewModel.sort == .newest ? $0.openedAt > $1.openedAt : $0.openedAt < $1.openedAt }
    }
}

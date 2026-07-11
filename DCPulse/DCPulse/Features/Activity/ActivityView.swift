import SwiftUI

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @Environment(PulseDataStore.self) private var store
    var body: some View {
        List {
            Section { Label("Within \(store.radius.label) · Last 30 days", systemImage: "line.3.horizontal.decrease.circle").foregroundStyle(.secondary) }
            Section("Timeline") {
                ForEach(sortedItems) { item in NavigationLink(value: item) { PulseItemRow(item: item) } }
                pagingFooter
            }
        }
        .navigationTitle("Activity")
        .toolbar { Picker("Sort", selection: $viewModel.sort) { ForEach(ActivityViewModel.Sort.allCases, id: \.self) { Text($0.rawValue) } } }
        .navigationDestination(for: PulseItem.self) { ItemDetailsView(item: $0) }
        .overlay { if store.isLoading { SearchLoadingOverlay(placeName: store.placeName, radius: store.radius) } }
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
        store.items.sorted { viewModel.sort == .newest ? $0.openedAt > $1.openedAt : $0.openedAt < $1.openedAt }
    }
}

import SwiftUI

struct StatusItemsView: View {
    let status: PulseItem.Status
    @Environment(PulseDataStore.self) private var store

    var body: some View {
        List {
            Section {
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
            Section("\(items.count) request\(items.count == 1 ? "" : "s")") {
                ForEach(items) { item in
                    NavigationLink { ItemDetailsView(item: item) } label: { PulseItemRow(item: item) }
                        .accessibilityIdentifier("status.item")
                }
                if store.isLoadingMore {
                    HStack { Spacer(); ProgressView("Loading more…"); Spacer() }
                } else if store.hasMore {
                    HStack { Spacer(); ProgressView("Loading more…"); Spacer() }
                        .task { await store.loadMore() }
                }
            }
        }
        .navigationTitle(status.displayName)
    }

    private var items: [PulseItem] {
        store.items.filter { $0.id.source == .serviceRequests311 && $0.status == status }
    }
    private var description: String {
        switch status {
        case .new: "Unresolved requests submitted within the last 48 hours."
        case .active: "Unresolved requests more than 48 hours old."
        case .resolved: "Requests reported by DC as closed, completed, or resolved."
        case .unknown: "Requests whose source status could not be normalized."
        }
    }
}

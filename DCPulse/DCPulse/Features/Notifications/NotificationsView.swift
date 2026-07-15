import SwiftData
import SwiftUI

struct NotificationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InAppNotification.createdAt, order: .reverse)
    private var notifications: [InAppNotification]
    @Query private var watchedItems: [WatchedPulseItem]
    @State private var selectedItem: PulseItem?

    var body: some View {
        Group {
            if notifications.isEmpty {
                ContentUnavailableView(
                    "No notifications yet",
                    systemImage: "bell",
                    description: Text("Updates to watched requests and new items discovered near home will appear here.")
                )
            } else {
                List {
                    if !unread.isEmpty {
                        Section("New") {
                            ForEach(unread) { notificationRow($0) }
                                .onDelete { delete($0, from: unread) }
                        }
                    }
                    if !read.isEmpty {
                        Section("Earlier") {
                            ForEach(read) { notificationRow($0) }
                                .onDelete { delete($0, from: read) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationDestination(item: $selectedItem) { item in
            ItemDetailsView(item: item)
        }
        .toolbar {
            if !notifications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !unread.isEmpty {
                            Button { markAllRead() } label: {
                                Label("Mark All as Read", systemImage: "checkmark.circle")
                            }
                        }
                        Button(role: .destructive) { deleteAll() } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Notification actions")
                }
            }
        }
    }

    private var unread: [InAppNotification] { notifications.filter(\.isUnread) }
    private var read: [InAppNotification] { notifications.filter { !$0.isUnread } }

    @ViewBuilder
    private func notificationRow(_ notification: InAppNotification) -> some View {
        if let item = notification.item {
            Button {
                selectedItem = item
                markRead(notification)
            } label: {
                NotificationRow(notification: notification)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("notifications.item")
        } else {
            Button { markRead(notification) } label: {
                NotificationRow(notification: notification)
            }
            .buttonStyle(.plain)
        }
    }

    private func markRead(_ notification: InAppNotification) {
        notification.markRead()
        markWatchSeen(for: notification)
        try? modelContext.save()
    }

    private func markAllRead() {
        unread.forEach {
            $0.markRead()
            markWatchSeen(for: $0)
        }
        try? modelContext.save()
    }

    private func delete(_ offsets: IndexSet, from collection: [InAppNotification]) {
        offsets.forEach { modelContext.delete(collection[$0]) }
        try? modelContext.save()
    }

    private func deleteAll() {
        notifications.forEach { markWatchSeen(for: $0) }
        notifications.forEach(modelContext.delete)
        try? modelContext.save()
    }

    private func markWatchSeen(for notification: InAppNotification) {
        guard let item = notification.item else { return }
        let key = WatchedPulseItem.stableKey(for: item.id)
        watchedItems.first { $0.stableKey == key }?.markStatusChangeSeen()
    }
}

private struct NotificationRow: View {
    let notification: InAppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notification.title)
                        .font(.subheadline.weight(notification.isUnread ? .semibold : .regular))
                    Spacer(minLength: 8)
                    if notification.isUnread {
                        Circle().fill(.indigo).frame(width: 8, height: 8)
                            .accessibilityLabel("Unread")
                    }
                }
                Text(notification.message)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                Text(notification.createdAt, format: .relative(presentation: .named))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch notification.kind {
        case .statusChanged: "arrow.triangle.2.circlepath"
        case .newNearbyItem: "location.badge.plus"
        }
    }

    private var color: Color {
        switch notification.kind {
        case .statusChanged: .orange
        case .newNearbyItem: .indigo
        }
    }
}

#Preview {
    NavigationStack { NotificationsView() }
        .modelContainer(for: InAppNotification.self, inMemory: true)
}

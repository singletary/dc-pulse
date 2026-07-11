import SwiftUI

struct PulseItemRow: View {
    let item: PulseItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.category).font(.caption).foregroundStyle(.secondary)
                Spacer()
                StatusPill(status: item.status)
            }
            Text(item.title).font(.headline)
            if let address = item.address {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                Text(item.id.source.displayName)
                Spacer()
                Text(item.openedAt, style: .relative)
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

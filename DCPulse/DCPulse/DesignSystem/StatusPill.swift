import SwiftUI

struct StatusPill: View {
    let status: PulseItem.Status

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel("Status: \(status.displayName)")
    }

    private var color: Color {
        switch status {
        case .new: .blue
        case .active: .orange
        case .resolved: .green
        case .unknown: .secondary
        }
    }
}

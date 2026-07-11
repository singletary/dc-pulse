import SwiftUI

struct SearchLoadingOverlay: View {
    let placeName: String
    let radius: PulseDataStore.Radius

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            Text("Loading nearby activity")
                .font(.headline)
            Text("\(placeName) · \(radius.label) · Last 30 days")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading activity near \(placeName), within \(radius.label), from the last 30 days")
    }
}

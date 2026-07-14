import SwiftUI

struct SearchLoadingOverlay: View {
    let placeName: String
    let radius: PulseDataStore.Radius
    let period: PulseDataStore.Period

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            Text("Loading nearby requests")
                .font(.headline)
            Text("\(placeName) · \(radius.label) · \(period.label)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading requests near \(placeName), within \(radius.label)")
    }
}

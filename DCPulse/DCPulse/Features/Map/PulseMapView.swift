import MapKit
import SwiftUI

struct PulseMapView: View {
    @State private var viewModel = PulseMapViewModel()
    @State private var selectedItem: PulseItem?
    @Environment(PulseDataStore.self) private var store

    var body: some View {
        Map(position: $viewModel.position, selection: $selectedItem) {
            ForEach(store.items.filter { $0.coordinate != nil }) { item in
                Marker(item.title, systemImage: icon(for: item), coordinate: item.coordinate!.clLocationCoordinate)
                    .tint(color(for: item.status)).tag(item)
            }
        }
        .safeAreaInset(edge: .top) {
            Label("All layers · 1 mile · 30 days", systemImage: "line.3.horizontal.decrease.circle.fill")
                .font(.subheadline.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule()).padding(.top, 8)
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedItem) { item in NavigationStack { ItemDetailsView(item: item) } }
    }

    private func icon(for item: PulseItem) -> String {
        switch item.id.source { case .serviceRequests311: "wrench.and.screwdriver"; case .buildingPermits2026: "building.2"; case .ddotConstructionPermits2026: "road.lanes" }
    }
    private func color(for status: PulseItem.Status) -> Color {
        switch status { case .new: .blue; case .active: .orange; case .resolved: .green; case .unknown: .gray }
    }
}

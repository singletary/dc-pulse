import SwiftUI

struct PlacesView: View {
    @State private var viewModel = PlacesViewModel()
    @Environment(PulseDataStore.self) private var store
    @Environment(LocationService.self) private var locationService
    var body: some View {
        List {
            Section("Current search area") {
                Label {
                    VStack(alignment: .leading) {
                        Text(store.placeName).font(.headline)
                        Text("1 mile · Last 30 days").font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: store.placeName == "Current Location" ? "location.fill" : "building.columns.fill").foregroundStyle(.indigo) }
                if store.placeName != "Current Location" {
                    Button("Use My Location") { locationService.requestCurrentLocation() }
                }
            }
            Section {
                ForEach(viewModel.places) { place in
                    Label { VStack(alignment: .leading) { Text(place.name).font(.headline); Text(place.detail).font(.subheadline).foregroundStyle(.secondary) } } icon: { Image(systemName: place.systemImage).foregroundStyle(.indigo) }
                }
            } header: { Text("Following") } footer: { Text("Saved-place persistence and notifications are planned for a later phase.") }
            Section { Button { } label: { Label("Follow another place", systemImage: "plus.circle") } }
        }
        .navigationTitle("Places")
    }
}

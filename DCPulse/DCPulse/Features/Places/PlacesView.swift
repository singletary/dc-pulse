import SwiftUI

struct PlacesView: View {
    @State private var viewModel = PlacesViewModel()
    var body: some View {
        List {
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

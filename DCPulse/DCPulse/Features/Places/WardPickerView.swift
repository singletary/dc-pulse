import SwiftUI

struct WardPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PulseDataStore.self) private var store
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        NavigationStack {
            List(DCWard.all) { ward in
                Button {
                    navigation.selectedTab = .map
                    dismiss()
                    Task {
                        await store.load(coordinate: ward.coordinate, placeName: ward.name, force: true)
                        await store.prefetchSummary()
                    }
                } label: {
                    HStack {
                        Label(ward.name, systemImage: "building.columns")
                        Spacer()
                        if store.placeName == ward.name { Image(systemName: "checkmark").foregroundStyle(.indigo) }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Browse by Ward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

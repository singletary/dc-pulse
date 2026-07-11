import SwiftUI

struct WardPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PulseDataStore.self) private var store

    var body: some View {
        NavigationStack {
            List(DCWard.all) { ward in
                Button {
                    Task {
                        await store.load(coordinate: ward.coordinate, placeName: ward.name, force: true)
                        dismiss()
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

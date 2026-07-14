import MapKit
import SwiftUI

struct HomeAddressEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeLocationStore.self) private var homeLocation
    @State private var address = ""
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Home address in Washington, DC") {
                    TextField("Street address", text: $address, prompt: Text("Enter a home address"))
                        .textContentType(.fullStreetAddress).submitLabel(.done).onSubmit(save)
                    Button("Save Home Address") { save() }.disabled(trimmed.isEmpty || isSearching)
                }
                if isSearching { ProgressView("Finding address…") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Save Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }

    private var trimmed: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmed.isEmpty, !isSearching else { return }
        isSearching = true; errorMessage = nil
        Task {
            defer { isSearching = false }
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "\(trimmed), Washington, DC"
                request.resultTypes = .address
                request.region = .init(center: SampleData.center.clLocationCoordinate,
                                       span: .init(latitudeDelta: 0.25, longitudeDelta: 0.25))
                guard let result = try await MKLocalSearch(request: request).start().mapItems.first,
                      let coordinate = PulseItem.Coordinate(latitude: result.location.coordinate.latitude,
                                                            longitude: result.location.coordinate.longitude),
                      coordinate.isWithinDCServiceArea else {
                    errorMessage = "Enter an address located in Washington, DC."
                    return
                }
                homeLocation.save(address: result.address?.shortAddress ?? trimmed, coordinate: coordinate)
                dismiss()
            } catch { errorMessage = "We couldn’t find that address. Check it and try again." }
        }
    }
}

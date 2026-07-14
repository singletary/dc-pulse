import MapKit
import SwiftUI
import SwiftData

struct AddressSearchView: View {
    enum Mode: Equatable { case search, follow }

    var mode: Mode = .search
    @Environment(\.dismiss) private var dismiss
    @Environment(PulseDataStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query private var followedPlaces: [FollowedPlace]
    @State private var query = ""
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Street address", text: $query, prompt: Text("Enter a DC address"))
                        .textContentType(.fullStreetAddress)
                        .submitLabel(.search)
                        .onSubmit(search)
                    Button("Search") { search() }
                        .disabled(trimmedQuery.isEmpty || isSearching)
                } header: {
                    Text("Washington, DC address")
                } footer: {
                    Text("DC Pulse searches only within the Washington, DC service area.")
                }

                if isSearching {
                    HStack { Spacer(); ProgressView("Finding address…"); Spacer() }
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Address not found",
                        systemImage: "mappin.slash",
                        description: Text(errorMessage)
                    )
                }
            }
            .navigationTitle(mode == .search ? "Search Address" : "Follow a Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func search() {
        guard !trimmedQuery.isEmpty, !isSearching else { return }
        isSearching = true
        errorMessage = nil

        Task {
            defer { isSearching = false }
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "\(trimmedQuery), Washington, DC"
                request.resultTypes = .address
                request.region = MKCoordinateRegion(
                    center: SampleData.center.clLocationCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
                )
                let response = try await MKLocalSearch(request: request).start()
                guard let mapItem = response.mapItems.first,
                      let coordinate = PulseItem.Coordinate(
                        latitude: mapItem.location.coordinate.latitude,
                        longitude: mapItem.location.coordinate.longitude
                      ),
                      coordinate.isWithinDCServiceArea else {
                    errorMessage = "Enter an address located in Washington, DC, or browse by ward."
                    return
                }

                let address = mapItem.address?.shortAddress ?? trimmedQuery
                let name = mapItem.name ?? address
                if mode == .follow {
                    let key = FollowedPlace.stableKey(for: coordinate)
                    if let existing = followedPlaces.first(where: { $0.stableKey == key }) {
                        existing.name = name
                        existing.address = address
                    } else {
                        modelContext.insert(FollowedPlace(name: name, address: address, coordinate: coordinate))
                    }
                    try? modelContext.save()
                } else {
                    await store.load(coordinate: coordinate, placeName: address, force: true)
                    await store.prefetchSummary()
                }
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = "We couldn’t search for that address. Check the address and try again."
            }
        }
    }
}

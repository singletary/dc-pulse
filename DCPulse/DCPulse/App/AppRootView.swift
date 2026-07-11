import SwiftUI

struct AppRootView: View {
    @State private var store = PulseDataStore()
    @State private var locationService = LocationService()

    var body: some View {
        TabView {
            Tab("Pulse", systemImage: "waveform.path.ecg") { NavigationStack { PulseView() } }
            Tab("Map", systemImage: "map") { NavigationStack { PulseMapView() } }
            Tab("Activity", systemImage: "clock.arrow.circlepath") { NavigationStack { ActivityView() } }
            Tab("Places", systemImage: "bookmark") { NavigationStack { PlacesView() } }
        }
        .tint(.indigo)
        .environment(store)
        .environment(locationService)
        .task { await store.load() }
        .onChange(of: locationService.updateSequence) { _, _ in
            guard let coordinate = locationService.coordinate else { return }
            Task { await store.load(coordinate: coordinate, placeName: "Current Location", force: true) }
        }
    }
}

#Preview { AppRootView() }

import SwiftUI

struct AppRootView: View {
    @State private var store = PulseDataStore()

    var body: some View {
        TabView {
            Tab("Pulse", systemImage: "waveform.path.ecg") { NavigationStack { PulseView() } }
            Tab("Map", systemImage: "map") { NavigationStack { PulseMapView() } }
            Tab("Activity", systemImage: "clock.arrow.circlepath") { NavigationStack { ActivityView() } }
            Tab("Places", systemImage: "bookmark") { NavigationStack { PlacesView() } }
        }
        .tint(.indigo)
        .environment(store)
        .task { await store.load() }
    }
}

#Preview { AppRootView() }

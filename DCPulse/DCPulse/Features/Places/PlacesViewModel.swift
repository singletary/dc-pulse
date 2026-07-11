import Observation

@Observable final class PlacesViewModel {
    struct Place: Identifiable { let id: String; let name: String; let detail: String; let systemImage: String }
    var places = [Place(id: "downtown", name: "Downtown DC", detail: "1 mile · Last 30 days", systemImage: "location.fill")]
}

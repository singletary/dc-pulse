import Foundation
import Observation

@MainActor @Observable
final class PulseDataStore {
    enum State: Equatable { case idle, loading, loaded, empty, failed(String) }

    private let repository: any PulseRepositoryProtocol
    var items: [PulseItem] = []
    var state: State = .idle
    private(set) var searchCoordinate = SampleData.center
    private(set) var placeName = "Downtown DC"

    init() {
        repository = ServiceRequest311Repository()
    }

    init(repository: any PulseRepositoryProtocol) {
        self.repository = repository
    }

    func load(
        coordinate requestedCoordinate: PulseItem.Coordinate? = nil,
        placeName: String = "Downtown DC",
        force: Bool = false
    ) async {
        guard force || state == .idle || isFailure else { return }
        let coordinate = requestedCoordinate ?? SampleData.center
        searchCoordinate = coordinate
        self.placeName = placeName
        state = .loading
        do {
            let liveItems = try await repository.nearbyItems(coordinate: coordinate, radiusMiles: 1, days: 30)
            items = liveItems
            state = liveItems.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func retry() async { await load(coordinate: searchCoordinate, placeName: placeName, force: true) }

    private var isFailure: Bool { if case .failed = state { true } else { false } }
}

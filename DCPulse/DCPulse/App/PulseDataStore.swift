import Foundation
import Observation

@MainActor @Observable
final class PulseDataStore {
    enum State: Equatable { case idle, loading, loaded, empty, failed(String) }

    private let repository: any PulseRepositoryProtocol
    var items: [PulseItem] = []
    var state: State = .idle

    init() {
        repository = ServiceRequest311Repository()
    }

    init(repository: any PulseRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        guard state == .idle || isFailure else { return }
        state = .loading
        do {
            let liveItems = try await repository.nearbyItems(coordinate: SampleData.center, radiusMiles: 1, days: 30)
            items = liveItems
            state = liveItems.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func retry() async { state = .idle; await load() }

    private var isFailure: Bool { if case .failed = state { true } else { false } }
}

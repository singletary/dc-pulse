import Foundation
import Observation

@MainActor @Observable
final class PulseDataStore {
    static let pageSize = 30

    enum Radius: Double, CaseIterable, Identifiable {
        case quarterMile = 0.25
        case halfMile = 0.5
        case oneMile = 1

        var id: Double { rawValue }
        var label: String { rawValue == 1 ? "1 mile" : "\(rawValue.formatted()) mile" }
    }

    enum State: Equatable { case idle, loading, loaded, empty, failed(String) }

    private let repository: any PulseRepositoryProtocol
    private var loadSequence = 0
    private var nextOffset = 0
    var items: [PulseItem] = []
    var state: State = .idle
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var loadMoreError: String?
    private(set) var searchCoordinate = SampleData.center
    private(set) var placeName = "Downtown DC"
    private(set) var radius: Radius = .halfMile

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
        loadSequence += 1
        let requestSequence = loadSequence
        state = .loading
        hasMore = false
        isLoadingMore = false
        loadMoreError = nil
        nextOffset = 0
        do {
            let page = try await repository.nearbyItems(
                coordinate: coordinate,
                radiusMiles: radius.rawValue,
                days: 30,
                offset: 0,
                limit: Self.pageSize
            )
            guard requestSequence == loadSequence else { return }
            items = page.items
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            state = page.items.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            guard requestSequence == loadSequence else { return }
            state = .idle
        } catch {
            guard requestSequence == loadSequence else { return }
            state = .failed(error.localizedDescription)
        }
    }

    func loadMore() async {
        guard state == .loaded, hasMore, !isLoadingMore else { return }
        let requestSequence = loadSequence
        let requestedOffset = nextOffset
        isLoadingMore = true
        loadMoreError = nil
        defer {
            if requestSequence == loadSequence { isLoadingMore = false }
        }

        do {
            let page = try await repository.nearbyItems(
                coordinate: searchCoordinate,
                radiusMiles: radius.rawValue,
                days: 30,
                offset: requestedOffset,
                limit: Self.pageSize
            )
            guard requestSequence == loadSequence else { return }
            let existingIDs = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            nextOffset = page.nextOffset
            hasMore = page.hasMore
        } catch is CancellationError {
            return
        } catch {
            guard requestSequence == loadSequence else { return }
            loadMoreError = error.localizedDescription
        }
    }

    func retry() async { await load(coordinate: searchCoordinate, placeName: placeName, force: true) }

    func selectRadius(_ radius: Radius) async {
        guard radius != self.radius else { return }
        self.radius = radius
        await load(coordinate: searchCoordinate, placeName: placeName, force: true)
    }

    var isLoading: Bool { state == .loading }
    var coordinateDescription: String {
        "\(searchCoordinate.latitude.formatted(.number.precision(.fractionLength(4)))), \(searchCoordinate.longitude.formatted(.number.precision(.fractionLength(4))))"
    }

    private var isFailure: Bool { if case .failed = state { true } else { false } }
}

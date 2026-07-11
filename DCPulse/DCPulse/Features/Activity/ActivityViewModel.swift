import Foundation
import Observation

@Observable final class ActivityViewModel {
    enum Sort: String, CaseIterable { case newest = "Newest", oldest = "Oldest" }
    var sort: Sort = .newest
    var items: [PulseItem] {
        SampleData.items.sorted { sort == .newest ? $0.openedAt > $1.openedAt : $0.openedAt < $1.openedAt }
    }
}

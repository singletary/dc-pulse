import Foundation
import Observation

@Observable
final class PulseViewModel {
    let radiusMiles = 1
    let periodDays = 30
    var items: [PulseItem] = []

    var activeCount: Int { items.filter { $0.status == .active }.count }
    var newCount: Int { items.filter { $0.status == .new }.count }
    var resolvedCount: Int { items.filter { $0.status == .resolved }.count }
}

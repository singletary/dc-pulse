import Foundation

struct RequestStatusCounts: Codable, Equatable, Sendable {
    let new: Int
    let active: Int
    let resolved: Int

    subscript(status: PulseItem.Status) -> Int? {
        switch status {
        case .new: new
        case .active: active
        case .resolved: resolved
        case .unknown: nil
        }
    }
}

protocol RequestStatusSummaryRepositoryProtocol: Sendable {
    func statusCounts(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int
    ) async throws -> RequestStatusCounts
}

import Foundation
import SwiftData

@Model
final class FollowedPlace {
    @Attribute(.unique) var stableKey: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var followedAt: Date

    @MainActor init(name: String, address: String, coordinate: PulseItem.Coordinate, followedAt: Date = .now) {
        stableKey = Self.stableKey(for: coordinate)
        self.name = name
        self.address = address
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        self.followedAt = followedAt
    }

    @MainActor var coordinate: PulseItem.Coordinate? {
        PulseItem.Coordinate(latitude: latitude, longitude: longitude)
    }

    @MainActor static func stableKey(for coordinate: PulseItem.Coordinate) -> String {
        "\((coordinate.latitude * 10_000).rounded()):\((coordinate.longitude * 10_000).rounded())"
    }

    @MainActor static func matches(
        address: String,
        coordinate: PulseItem.Coordinate,
        followedAddress: String,
        followedStableKey: String
    ) -> Bool {
        followedStableKey == stableKey(for: coordinate)
            || normalizedAddress(followedAddress) == normalizedAddress(address)
    }

    private static func normalizedAddress(_ address: String) -> String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

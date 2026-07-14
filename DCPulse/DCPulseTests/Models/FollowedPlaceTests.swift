import Foundation
import Testing
@testable import DCPulse

@MainActor
struct FollowedPlaceTests {
    @Test func retainsCoordinateAndUsesStableRoundedIdentity() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.900012, longitude: -77.030012))
        let nearbyCoordinate = try #require(PulseItem.Coordinate(latitude: 38.900014, longitude: -77.030014))
        let place = FollowedPlace(name: "Home", address: "9999 Example Avenue NW", coordinate: coordinate)

        #expect(place.coordinate == coordinate)
        #expect(FollowedPlace.stableKey(for: coordinate) == FollowedPlace.stableKey(for: nearbyCoordinate))
    }

    @Test func matchesEquivalentAddressesAndCoordinates() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.900012, longitude: -77.030012))
        let elsewhere = try #require(PulseItem.Coordinate(latitude: 38.92, longitude: -77.04))

        #expect(FollowedPlace.matches(
            address: "9999 Example Ave. NW",
            coordinate: elsewhere,
            followedAddress: "  9999 Example Ave, NW ",
            followedStableKey: FollowedPlace.stableKey(for: coordinate)
        ))
        #expect(FollowedPlace.matches(
            address: "Different address",
            coordinate: coordinate,
            followedAddress: "9999 Example Ave NW",
            followedStableKey: FollowedPlace.stableKey(for: coordinate)
        ))
    }
}

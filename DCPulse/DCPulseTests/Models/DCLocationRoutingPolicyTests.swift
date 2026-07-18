import Testing
@testable import DCPulse

struct DCLocationRoutingPolicyTests {
    @Test func preservesLocationsInsideTheDCServiceArea() throws {
        let coordinate = try #require(PulseItem.Coordinate(latitude: 38.91, longitude: -77.03))

        let resolution = DCLocationRoutingPolicy().resolve(coordinate)

        #expect(resolution == .current(coordinate))
        #expect(resolution.placeName == "Current Location")
    }

    @Test func routesNearbyOutsideLocationsToAUsableDCBorderCenter() throws {
        let silverSpring = try #require(PulseItem.Coordinate(latitude: 39.02, longitude: -77.02))

        let resolution = DCLocationRoutingPolicy().resolve(silverSpring)

        guard case .nearbyBorder(let coordinate) = resolution else {
            Issue.record("Expected a nearby DC border resolution")
            return
        }
        #expect(coordinate.isWithinDCServiceArea)
        #expect(resolution.placeName == "Near the DC Border")
    }

    @Test func routesDistantLocationsToTheStablePublicFallback() throws {
        let distant = try #require(PulseItem.Coordinate(latitude: 40.7128, longitude: -74.0060))

        let resolution = DCLocationRoutingPolicy().resolve(distant)

        #expect(resolution == .defaultDC(DCLocationRoutingPolicy.defaultCoordinate))
        #expect(resolution.searchCoordinate == DCLocationRoutingPolicy.defaultCoordinate)
        #expect(resolution.placeName == "Downtown DC")
    }

    @Test func positiveLongitudeSimulatorMistakeCannotBecomeASearchCenter() throws {
        let malformedDC = try #require(PulseItem.Coordinate(latitude: 38.90, longitude: 77.03))

        let resolution = DCLocationRoutingPolicy().resolve(malformedDC)

        #expect(resolution == .defaultDC(DCLocationRoutingPolicy.defaultCoordinate))
    }
}

import CoreLocation
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

    @Test(arguments: [
        (38.79, -77.03),
        (39.00, -77.03),
        (38.90, -77.13),
        (38.90, -76.90)
    ])
    func preservesEveryInclusiveSideOfTheServiceEnvelope(
        latitude: Double,
        longitude: Double
    ) throws {
        let coordinate = try #require(PulseItem.Coordinate(
            latitude: latitude,
            longitude: longitude
        ))

        #expect(DCLocationRoutingPolicy().resolve(coordinate) == .current(coordinate))
    }

    @Test(arguments: [
        (38.789, -77.03),
        (39.001, -77.03),
        (38.90, -77.131),
        (38.90, -76.899)
    ])
    func routesEveryJustOutsideSideToAnInsetBorderCoordinate(
        latitude: Double,
        longitude: Double
    ) throws {
        let coordinate = try #require(PulseItem.Coordinate(
            latitude: latitude,
            longitude: longitude
        ))
        let resolution = DCLocationRoutingPolicy().resolve(coordinate)
        guard case .nearbyBorder(let border) = resolution else {
            Issue.record("Expected nearby border routing")
            return
        }

        #expect(border.isWithinDCServiceArea)
        #expect(border.latitude > PulseItem.Coordinate.dcLatitudeRange.lowerBound)
        #expect(border.latitude < PulseItem.Coordinate.dcLatitudeRange.upperBound)
        #expect(border.longitude > PulseItem.Coordinate.dcLongitudeRange.lowerBound)
        #expect(border.longitude < PulseItem.Coordinate.dcLongitudeRange.upperBound)
    }

    @Test func appliesTheTwentyFiveMileThresholdOnBothSides() throws {
        let border = try #require(PulseItem.Coordinate(latitude: 39.0, longitude: -77.03))
        let near = try #require(PulseItem.Coordinate(latitude: 39.35, longitude: -77.03))
        let far = try #require(PulseItem.Coordinate(latitude: 39.40, longitude: -77.03))
        let borderLocation = CLLocation(
            latitude: border.latitude,
            longitude: border.longitude
        )

        #expect(CLLocation(latitude: near.latitude, longitude: near.longitude)
            .distance(from: borderLocation) < 25 * 1_609.344)
        #expect(CLLocation(latitude: far.latitude, longitude: far.longitude)
            .distance(from: borderLocation) > 25 * 1_609.344)
        guard case .nearbyBorder = DCLocationRoutingPolicy().resolve(near) else {
            Issue.record("Expected the under-25-mile coordinate to use the border")
            return
        }
        #expect(DCLocationRoutingPolicy().resolve(far) == .defaultDC(
            DCLocationRoutingPolicy.defaultCoordinate
        ))
    }

    @Test func approximateCoordinateUsesTheSamePrivacyPreservingRoute() throws {
        let approximate = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 39.02, longitude: -77.02),
            altitude: 0,
            horizontalAccuracy: 5_000,
            verticalAccuracy: -1,
            timestamp: .now
        )
        let coordinate = try #require(PulseItem.Coordinate(
            latitude: approximate.coordinate.latitude,
            longitude: approximate.coordinate.longitude
        ))

        guard case .nearbyBorder(let border) = DCLocationRoutingPolicy().resolve(coordinate) else {
            Issue.record("Expected approximate nearby location to stay inside the DC query envelope")
            return
        }
        #expect(border.isWithinDCServiceArea)
    }
}

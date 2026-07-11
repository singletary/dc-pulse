import Testing
@testable import DCPulse

struct DCWardTests {
    @Test func providesEightDistinctValidSearchCenters() {
        #expect(DCWard.all.map(\.number) == Array(1...8))
        #expect(Set(DCWard.all.map(\.coordinate)).count == 8)
        #expect(DCWard.all.allSatisfy { $0.coordinate.latitude > 38.8 && $0.coordinate.latitude < 39.0 })
        #expect(DCWard.all.allSatisfy { $0.coordinate.longitude > -77.1 && $0.coordinate.longitude < -76.9 })
    }
}

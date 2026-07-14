import Foundation

struct DCWard: Identifiable, Hashable, Sendable {
    let number: Int
    let coordinate: PulseItem.Coordinate

    var id: Int { number }
    var name: String { "Ward \(number)" }

    static let all: [DCWard] = [
        DCWard(number: 1, coordinate: .init(latitude: 38.92601, longitude: -77.03153)!),
        DCWard(number: 2, coordinate: .init(latitude: 38.89630, longitude: -77.04825)!),
        DCWard(number: 3, coordinate: .init(latitude: 38.93710, longitude: -77.08015)!),
        DCWard(number: 4, coordinate: .init(latitude: 38.96539, longitude: -77.03159)!),
        DCWard(number: 5, coordinate: .init(latitude: 38.92718, longitude: -76.98055)!),
        DCWard(number: 6, coordinate: .init(latitude: 38.87978, longitude: -77.00739)!),
        DCWard(number: 7, coordinate: .init(latitude: 38.88523, longitude: -76.94640)!),
        DCWard(number: 8, coordinate: .init(latitude: 38.83608, longitude: -77.00483)!)
    ]
}

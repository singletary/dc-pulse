import Foundation

enum DC311RequestHandoff {
    static let officialURL = URL(string: "https://311.dc.gov")!

    static func instruction(for requestID: String) -> String {
        "DC Pulse copied request \(requestID). Paste that ID into DC 311 to check the official status."
    }
}

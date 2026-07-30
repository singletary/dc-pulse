import Foundation

enum DC311RequestHandoff {
    static let officialURL = URL(string: "https://311.dc.gov")!
    static let statusTextURL = URL(string: "sms:32311")!

    static func instruction(for requestID: String) -> String {
        "DC Pulse copied request \(normalizedIdentifier(requestID)). Paste it into the app or website, or send STATUS to Text DC311 and follow its prompts."
    }

    static func normalizedIdentifier(_ requestID: String) -> String {
        requestID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

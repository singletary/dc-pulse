import Foundation

enum AboutDestination: String, CaseIterable, Sendable {
    case website = "https://dcpulseapp.com"
    case support = "https://dcpulseapp.com/#support"
    case privacy = "https://dcpulseapp.com/#privacy"
    case sourceCode = "https://github.com/singletary/dc-pulse"
    case dataInformation = "https://dcpulseapp.com/#data"

    var url: URL { URL(string: rawValue)! }

    var accessibilityKey: String {
        switch self {
        case .website: "website"
        case .support: "support"
        case .privacy: "privacy"
        case .sourceCode: "source-code"
        case .dataInformation: "data-information"
        }
    }
}

enum AboutContent {
    static let independentDisclaimer = "DC Pulse is an independent application and is not affiliated with or endorsed by the Government of the District of Columbia. It does not create, manage, resolve, approve, or verify government requests or permits."

    static let dataAttribution = "DC Pulse uses public records published by DC 311, the DC Department of Buildings, the District Department of Transportation, and DC Open Data. Availability, accuracy, categorization, geocoding, and update timing remain the responsibility of the source agencies."

    static let license = """
    MIT License

    Copyright © 2026 Michael Singletary

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """

    static func versionDescription(
        shortVersion: String?,
        build: String?
    ) -> String {
        let version = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = build?.trimmingCharacters(in: .whitespacesAndNewlines)
        return switch (version?.isEmpty == false ? version : nil, build?.isEmpty == false ? build : nil) {
        case let (version?, build?): "Version \(version) (\(build))"
        case let (version?, nil): "Version \(version)"
        case let (nil, build?): "Build \(build)"
        case (nil, nil): "Version unavailable"
        }
    }
}

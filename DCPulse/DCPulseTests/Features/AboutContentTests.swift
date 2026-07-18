import Foundation
import Testing
@testable import DCPulse

struct AboutContentTests {
    @Test func everyPublicDestinationIsSecureAndUnique() {
        let destinations = AboutDestination.allCases.map(\.url)

        #expect(destinations.allSatisfy { $0.scheme == "https" })
        #expect(Set(destinations).count == destinations.count)
        #expect(AboutDestination.website.url.host == "dcpulseapp.com")
        #expect(AboutDestination.sourceCode.url.host == "github.com")
    }

    @Test func versionDescriptionHandlesCompleteAndMissingMetadata() {
        #expect(AboutContent.versionDescription(shortVersion: "1.0", build: "6") == "Version 1.0 (6)")
        #expect(AboutContent.versionDescription(shortVersion: "1.0", build: nil) == "Version 1.0")
        #expect(AboutContent.versionDescription(shortVersion: nil, build: "6") == "Build 6")
        #expect(AboutContent.versionDescription(shortVersion: " ", build: nil) == "Version unavailable")
    }

    @Test func essentialTrustTextRemainsAvailableOffline() {
        #expect(AboutContent.independentDisclaimer.contains("independent"))
        #expect(AboutContent.dataAttribution.contains("DC 311"))
        #expect(AboutContent.license.contains("MIT License"))
        #expect(AboutContent.license.contains("THE SOFTWARE IS PROVIDED"))
    }
}

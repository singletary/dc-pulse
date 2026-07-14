import Foundation
import Testing
@testable import DCPulse

@MainActor
struct XPostComposerTests {
    @Test func buildsNativeXComposeURLForInstalledApp() throws {
        let message = "@311DCGov Update on request 123?"
        let url = try #require(XPostComposer.nativeComposeURL(message: message))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.scheme == "twitter")
        #expect(components.host == "post")
        #expect(components.queryItems?.first(where: { $0.name == "message" })?.value == message)
    }

    @Test func buildsAReviewableXIntentWithoutLosingMessageContent() throws {
        let message = "@311DCGov Update on request 123? — Tree & sidewalk"
        let url = try #require(XPostComposer.composeURL(message: message))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.scheme == "https")
        #expect(components.host == "x.com")
        #expect(components.path == "/intent/post")
        #expect(components.queryItems?.first(where: { $0.name == "text" })?.value == message)
    }
}

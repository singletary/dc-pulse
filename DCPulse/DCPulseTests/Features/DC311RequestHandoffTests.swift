import Foundation
import Testing
@testable import DCPulse

struct DC311RequestHandoffTests {
    @Test func officialDestinationIsSecure() {
        #expect(DC311RequestHandoff.officialURL.scheme == "https")
        #expect(DC311RequestHandoff.officialURL.host == "311.dc.gov")
    }

    @Test func instructionNamesTheExactCopiedRequest() {
        let instruction = DC311RequestHandoff.instruction(for: "26-00012345")
        #expect(instruction.contains("26-00012345"))
        #expect(instruction.contains("Paste"))
        #expect(instruction.contains("official status"))
    }
}

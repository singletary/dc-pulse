import Foundation
import Testing
@testable import DCPulse

@MainActor
struct ArcGISResponseTests {
    @Test func decodesSuccessAndMissingOptionalFields() throws {
        let page = try JSONDecoder().decode(ArcGISFeaturePage.self, from: TestFixture.data(named: "arcgis-success"))
        #expect(page.features.count == 1)
        #expect(page.exceededTransferLimit == false)
        #expect(page.features[0].attributes["DETAIL"] == .null)
        #expect(page.features[0].geometry?.x == -77.0300)
    }

    @Test func decodesArcGISErrorEnvelope() throws {
        let envelope = try JSONDecoder().decode(ArcGISErrorEnvelope.self, from: TestFixture.data(named: "arcgis-error"))
        #expect(envelope.error.code == 400)
        #expect(envelope.error.details == ["Invalid where clause"])
    }

    @Test func decodesPaginationMetadataAndAbsentGeometry() throws {
        let page = try JSONDecoder().decode(ArcGISFeaturePage.self, from: TestFixture.data(named: "arcgis-page"))
        #expect(page.exceededTransferLimit)
        #expect(page.features.count == 2)
        #expect(page.features[0].geometry == nil)
    }

    @Test func emptyPayloadDefaultsToEmptyResults() throws {
        let page = try JSONDecoder().decode(ArcGISFeaturePage.self, from: Data("{}".utf8))
        #expect(page.features.isEmpty)
        #expect(!page.exceededTransferLimit)
    }

    @Test func decodesCountOnlyResponse() throws {
        let response = try JSONDecoder().decode(ArcGISCountResponse.self, from: Data(#"{"count":189}"#.utf8))
        #expect(response.count == 189)
    }
}

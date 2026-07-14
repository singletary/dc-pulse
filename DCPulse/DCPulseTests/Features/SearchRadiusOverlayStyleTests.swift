import MapKit
import Testing
@testable import DCPulse

@MainActor
struct SearchRadiusOverlayStyleTests {
    @Test func darkModeUsesStrongerRadiusContrast() {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        var lightStrokeAlpha: CGFloat = 0
        var darkStrokeAlpha: CGFloat = 0
        var lightFillAlpha: CGFloat = 0
        var darkFillAlpha: CGFloat = 0
        SearchRadiusOverlayStyle.strokeColor.resolvedColor(with: lightTraits)
            .getRed(nil, green: nil, blue: nil, alpha: &lightStrokeAlpha)
        SearchRadiusOverlayStyle.strokeColor.resolvedColor(with: darkTraits)
            .getRed(nil, green: nil, blue: nil, alpha: &darkStrokeAlpha)
        SearchRadiusOverlayStyle.fillColor.resolvedColor(with: lightTraits)
            .getRed(nil, green: nil, blue: nil, alpha: &lightFillAlpha)
        SearchRadiusOverlayStyle.fillColor.resolvedColor(with: darkTraits)
            .getRed(nil, green: nil, blue: nil, alpha: &darkFillAlpha)

        #expect(darkStrokeAlpha > lightStrokeAlpha)
        #expect(darkFillAlpha > lightFillAlpha)
    }

    @Test func removesFillWhenViewportIsEntirelyInsideSearchRadius() {
        let center = CLLocationCoordinate2D(latitude: 38.93, longitude: -77.03)
        let circle = MKCircle(center: center, radius: 804.672)
        let centerPoint = MKMapPoint(center)
        let closeViewport = MKMapRect(
            x: centerPoint.x - 200,
            y: centerPoint.y - 200,
            width: 400,
            height: 400
        )

        #expect(!SearchRadiusOverlayStyle.shouldShowFill(circle: circle, visibleMapRect: closeViewport))
    }

    @Test func keepsFillWhenSearchBoundaryProvidesContext() {
        let center = CLLocationCoordinate2D(latitude: 38.93, longitude: -77.03)
        let circle = MKCircle(center: center, radius: 804.672)

        #expect(SearchRadiusOverlayStyle.shouldShowFill(
            circle: circle,
            visibleMapRect: circle.boundingMapRect.insetBy(dx: -1_000, dy: -1_000)
        ))
    }
}

import MapKit
import SwiftUI

struct ClusteredPulseMap: UIViewRepresentable {
    let items: [PulseItem]
    let searchCoordinate: PulseItem.Coordinate
    let radiusMeters: CLLocationDistance
    let targetRegion: MKCoordinateRegion
    let centerRequestID: Int
    let onRegionChange: (CLLocationCoordinate2D) -> Void
    let onSelection: (RequestMapGroup) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Coordinator.itemReuseID)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Coordinator.clusterReuseID)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Coordinator.centerReuseID)
        context.coordinator.apply(parent: self, to: mapView, force: true)
        DispatchQueue.main.async {
            context.coordinator.enableItemRendering(on: mapView)
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.apply(parent: self, to: mapView, force: false)
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        static let itemReuseID = "pulse-item"
        static let clusterReuseID = "pulse-cluster"
        static let centerReuseID = "search-center"

        private var parent: ClusteredPulseMap
        private var renderedItemAnnotations: [PulseItem.ID: PulseItemAnnotation] = [:]
        private var renderedSearchCoordinate: PulseItem.Coordinate?
        private var renderedRadius: CLLocationDistance?
        private var appliedCenterRequestID = -1
        private var isApplyingRegion = false
        private var canRenderItems = false
        private var annotationUpdateTask: Task<Void, Never>?

        init(parent: ClusteredPulseMap) { self.parent = parent }

        func apply(parent: ClusteredPulseMap, to mapView: MKMapView, force: Bool) {
            self.parent = parent
            let searchCoordinateChanged = renderedSearchCoordinate != parent.searchCoordinate

            if force || appliedCenterRequestID != parent.centerRequestID {
                isApplyingRegion = true
                mapView.setRegion(parent.targetRegion, animated: !force)
                appliedCenterRequestID = parent.centerRequestID
            }

            if canRenderItems { updateItemAnnotations(with: parent.items, on: mapView) }

            if force || searchCoordinateChanged {
                mapView.removeAnnotations(mapView.annotations.filter { $0 is SearchCenterAnnotation })
                mapView.addAnnotation(SearchCenterAnnotation(coordinate: parent.searchCoordinate.clLocationCoordinate))
                renderedSearchCoordinate = parent.searchCoordinate
            }

            if force || searchCoordinateChanged || renderedRadius != parent.radiusMeters {
                mapView.removeOverlays(mapView.overlays)
                mapView.addOverlay(MKCircle(
                    center: parent.searchCoordinate.clLocationCoordinate,
                    radius: parent.radiusMeters
                ))
                renderedRadius = parent.radiusMeters
            }

        }

        func enableItemRendering(on mapView: MKMapView) {
            guard !canRenderItems else { return }
            canRenderItems = true
            updateItemAnnotations(with: parent.items, on: mapView)
        }

        private func updateItemAnnotations(with items: [PulseItem], on mapView: MKMapView) {
            annotationUpdateTask?.cancel()
            var desiredItems: [PulseItem.ID: PulseItem] = [:]
            for item in items where item.coordinate != nil { desiredItems[item.id] = item }

            let annotationsToRemove = renderedItemAnnotations.compactMap { id, annotation in
                guard let desired = desiredItems[id], desired == annotation.item else { return annotation }
                return nil
            }
            if !annotationsToRemove.isEmpty {
                mapView.removeAnnotations(annotationsToRemove)
                for annotation in annotationsToRemove { renderedItemAnnotations.removeValue(forKey: annotation.item.id) }
            }

            let annotationsToAdd = desiredItems.values.compactMap { item -> PulseItemAnnotation? in
                guard renderedItemAnnotations[item.id] == nil else { return nil }
                return PulseItemAnnotation(item)
            }
            guard !annotationsToAdd.isEmpty else { return }

            // Adding a large clustered result set in one MapKit transaction can block the
            // tab transition. Yield between small batches so the map becomes interactive
            // immediately while all records continue appearing over the next few frames.
            annotationUpdateTask = Task { @MainActor [weak self, weak mapView] in
                guard let self, let mapView else { return }
                for startIndex in stride(from: 0, to: annotationsToAdd.count, by: 30) {
                    guard !Task.isCancelled else { return }
                    await Task.yield()
                    let endIndex = min(startIndex + 30, annotationsToAdd.count)
                    let batch = Array(annotationsToAdd[startIndex..<endIndex]).filter {
                        self.renderedItemAnnotations[$0.item.id] == nil
                    }
                    guard !batch.isEmpty else { continue }
                    mapView.addAnnotations(batch)
                    for annotation in batch {
                        self.renderedItemAnnotations[annotation.item.id] = annotation
                    }
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            updateSearchRadiusAppearance(on: mapView)
            if isApplyingRegion {
                isApplyingRegion = false
                return
            }
            parent.onRegionChange(mapView.region.center)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.clusterReuseID,
                    for: cluster
                ) as! MKMarkerAnnotationView
                view.clusteringIdentifier = nil
                view.markerTintColor = .systemPurple
                view.glyphText = "\(cluster.memberAnnotations.count)"
                view.glyphImage = nil
                view.displayPriority = .required
                view.accessibilityLabel = "\(cluster.memberAnnotations.count) items in this area"
                return view
            }

            if let itemAnnotation = annotation as? PulseItemAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.itemReuseID,
                    for: itemAnnotation
                ) as! MKMarkerAnnotationView
                view.clusteringIdentifier = "pulse-items"
                view.markerTintColor = Self.color(for: itemAnnotation.item.status)
                view.glyphText = nil
                view.glyphImage = UIImage(systemName: Self.icon(for: itemAnnotation.item))
                view.displayPriority = .defaultHigh
                view.canShowCallout = false
                view.accessibilityLabel = "\(itemAnnotation.item.category), \(itemAnnotation.item.status.displayName)"
                return view
            }

            if annotation is SearchCenterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.centerReuseID,
                    for: annotation
                ) as! MKMarkerAnnotationView
                view.clusteringIdentifier = nil
                view.markerTintColor = .systemIndigo
                view.glyphImage = UIImage(systemName: "scope")
                view.glyphText = nil
                view.displayPriority = .required
                view.accessibilityLabel = "Search center"
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            let annotations: [PulseItemAnnotation]
            if let item = view.annotation as? PulseItemAnnotation {
                annotations = [item]
            } else if let cluster = view.annotation as? MKClusterAnnotation {
                annotations = cluster.memberAnnotations.compactMap { $0 as? PulseItemAnnotation }
            } else {
                return
            }
            guard !annotations.isEmpty,
                  let coordinate = PulseItem.Coordinate(
                    latitude: view.annotation?.coordinate.latitude ?? 0,
                    longitude: view.annotation?.coordinate.longitude ?? 0
                  ) else { return }
            let items = annotations.map(\.item).sorted { $0.openedAt > $1.openedAt }
            parent.onSelection(RequestMapGroup(coordinate: coordinate, items: items))
            mapView.deselectAnnotation(view.annotation, animated: false)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.strokeColor = SearchRadiusOverlayStyle.strokeColor
            renderer.lineWidth = 2
            applySearchRadiusAppearance(to: renderer, mapView: mapView)
            return renderer
        }

        private func updateSearchRadiusAppearance(on mapView: MKMapView) {
            for circle in mapView.overlays.compactMap({ $0 as? MKCircle }) {
                guard let renderer = mapView.renderer(for: circle) as? MKCircleRenderer else { continue }
                applySearchRadiusAppearance(to: renderer, mapView: mapView)
                renderer.setNeedsDisplay()
            }
        }

        private func applySearchRadiusAppearance(to renderer: MKCircleRenderer, mapView: MKMapView) {
            renderer.fillColor = SearchRadiusOverlayStyle.shouldShowFill(
                circle: renderer.circle,
                visibleMapRect: mapView.visibleMapRect
            ) ? SearchRadiusOverlayStyle.fillColor : .clear
        }

        private static func icon(for item: PulseItem) -> String {
            switch item.id.source {
            case .serviceRequests311: "wrench.and.screwdriver"
            case .buildingPermits2026: "building.2"
            case .ddotConstructionPermits2026: "road.lanes"
            }
        }

        private static func color(for status: PulseItem.Status) -> UIColor {
            switch status {
            case .new: .systemBlue
            case .active: .systemOrange
            case .resolved: .systemGreen
            case .unknown: .systemGray
            }
        }
    }
}

enum SearchRadiusOverlayStyle {
    static let strokeColor = UIColor { traits in
        UIColor.systemIndigo.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.95 : 0.65)
    }

    static let fillColor = UIColor { traits in
        UIColor.systemIndigo.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.20 : 0.10)
    }

    static func shouldShowFill(circle: MKCircle, visibleMapRect: MKMapRect) -> Bool {
        guard !visibleMapRect.isNull, !visibleMapRect.isEmpty else { return true }
        let center = MKMapPoint(circle.coordinate)
        let corners = [
            MKMapPoint(x: visibleMapRect.minX, y: visibleMapRect.minY),
            MKMapPoint(x: visibleMapRect.maxX, y: visibleMapRect.minY),
            MKMapPoint(x: visibleMapRect.minX, y: visibleMapRect.maxY),
            MKMapPoint(x: visibleMapRect.maxX, y: visibleMapRect.maxY)
        ]
        return !corners.allSatisfy { $0.distance(to: center) <= circle.radius }
    }
}

private final class PulseItemAnnotation: NSObject, MKAnnotation {
    let item: PulseItem
    let coordinate: CLLocationCoordinate2D
    var title: String? { item.title }

    init?(_ item: PulseItem) {
        guard let coordinate = item.coordinate else { return nil }
        self.item = item
        self.coordinate = coordinate.clLocationCoordinate
    }
}

private final class SearchCenterAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

struct RequestMapGroup: Identifiable, Hashable {
    let coordinate: PulseItem.Coordinate
    let items: [PulseItem]
    var id: String { "\(coordinate.latitude),\(coordinate.longitude):\(items.map(\.id.sourceIdentifier).joined(separator: ","))" }
}

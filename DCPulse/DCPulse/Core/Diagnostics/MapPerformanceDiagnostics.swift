import Foundation
import os

enum MapPerformanceStage: String, CaseIterable, Sendable {
    case coverageSession
    case coveragePass
    case sourceRequest
    case transport
    case decoding
    case mapping
    case merge
    case cacheEncoding
    case annotationDiff
    case annotationApply
}

enum MapPerformanceMilestone: String, CaseIterable, Sendable {
    case appLaunch
    case initialResults
    case selectedRadiusSeedReused
    case mapPresentation
    case mapInteractive
    case firstMarkers
    case coveragePage
    case closeInCoverage
    case selectedRadiusCoverage
    case boundedCoverage
    case clusteringStable
}

enum MapPerformanceOutcome: String, Sendable {
    case succeeded
    case partial
    case failed
    case cancelled
}

enum MapPerformanceSource: String, Sendable {
    case combined
    case dc311
    case buildingPermits
    case ddotPermits
    case otherArcGIS
}

enum MapPerformancePass: String, Sendable {
    case none
    case closeIn
    case selectedRadius
    case closeInAndSelected
}

struct MapPerformanceContext: Equatable, Sendable, CustomStringConvertible {
    let source: MapPerformanceSource
    let pass: MapPerformancePass
    let radiusBucket: String
    let offset: Int
    let limit: Int

    nonisolated init(
        source: MapPerformanceSource = .combined,
        pass: MapPerformancePass = .none,
        radiusMiles: Double? = nil,
        offset: Int = 0,
        limit: Int = 0
    ) {
        self.source = source
        self.pass = pass
        radiusBucket = Self.radiusBucket(for: radiusMiles)
        self.offset = offset
        self.limit = limit
    }

    nonisolated var description: String {
        "source=\(source.rawValue) pass=\(pass.rawValue) radius=\(radiusBucket) offset=\(offset) limit=\(limit)"
    }

    nonisolated static func endpoint(_ url: URL) -> MapPerformanceSource {
        let components = url.pathComponents
        guard let featureServerIndex = components.lastIndex(of: "FeatureServer"),
              featureServerIndex > components.startIndex else { return .otherArcGIS }
        switch components[components.index(before: featureServerIndex)] {
        case "ServiceRequests": return .dc311
        case "DCRA": return .buildingPermits
        case "DDOT": return .ddotPermits
        default: return .otherArcGIS
        }
    }

    nonisolated private static func radiusBucket(for radiusMiles: Double?) -> String {
        guard let radiusMiles else { return "none" }
        if abs(radiusMiles - 0.25) < 0.01 { return "0.25mi" }
        if abs(radiusMiles - 0.5) < 0.01 { return "0.5mi" }
        if abs(radiusMiles - 1) < 0.01 { return "1mi" }
        return "other"
    }
}

struct MapPerformanceInterval: @unchecked Sendable {
    let stage: MapPerformanceStage
    fileprivate let state: OSSignpostIntervalState?

    nonisolated init(stage: MapPerformanceStage, state: OSSignpostIntervalState?) {
        self.stage = stage
        self.state = state
    }
}

protocol MapPerformanceDiagnosticsProtocol: Sendable {
    nonisolated func begin(_ stage: MapPerformanceStage, context: MapPerformanceContext) -> MapPerformanceInterval
    nonisolated func end(
        _ interval: MapPerformanceInterval,
        outcome: MapPerformanceOutcome,
        itemCount: Int
    )
    nonisolated func milestone(
        _ milestone: MapPerformanceMilestone,
        context: MapPerformanceContext,
        itemCount: Int
    )
}

struct MapPerformanceDiagnostics: MapPerformanceDiagnosticsProtocol, Sendable {
    nonisolated static let shared = MapPerformanceDiagnostics()

    private let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dcpulseapp.DCPulse",
        category: "MapPerformance"
    )

    nonisolated func begin(_ stage: MapPerformanceStage, context: MapPerformanceContext) -> MapPerformanceInterval {
        let metadata = context.description
        let id = signposter.makeSignpostID()
        let state: OSSignpostIntervalState
        switch stage {
        case .coverageSession:
            state = signposter.beginInterval("Map Coverage Session", id: id, "\(metadata, privacy: .public)")
        case .coveragePass:
            state = signposter.beginInterval("Map Coverage Pass", id: id, "\(metadata, privacy: .public)")
        case .sourceRequest:
            state = signposter.beginInterval("Map Source Request", id: id, "\(metadata, privacy: .public)")
        case .transport:
            state = signposter.beginInterval("ArcGIS Transport", id: id, "\(metadata, privacy: .public)")
        case .decoding:
            state = signposter.beginInterval("ArcGIS Decoding", id: id, "\(metadata, privacy: .public)")
        case .mapping:
            state = signposter.beginInterval("Pulse Item Mapping", id: id, "\(metadata, privacy: .public)")
        case .merge:
            state = signposter.beginInterval("Map Item Merge", id: id, "\(metadata, privacy: .public)")
        case .cacheEncoding:
            state = signposter.beginInterval("Map Cache Encoding", id: id, "\(metadata, privacy: .public)")
        case .annotationDiff:
            state = signposter.beginInterval("Map Annotation Diff", id: id, "\(metadata, privacy: .public)")
        case .annotationApply:
            state = signposter.beginInterval("Map Annotation Apply", id: id, "\(metadata, privacy: .public)")
        }
        return MapPerformanceInterval(stage: stage, state: state)
    }

    nonisolated func end(
        _ interval: MapPerformanceInterval,
        outcome: MapPerformanceOutcome,
        itemCount: Int
    ) {
        guard let state = interval.state else { return }
        let outcome = outcome.rawValue
        switch interval.stage {
        case .coverageSession:
            signposter.endInterval("Map Coverage Session", state, "outcome=\(outcome, privacy: .public) count=\(itemCount)")
        case .coveragePass:
            signposter.endInterval("Map Coverage Pass", state, "outcome=\(outcome, privacy: .public) count=\(itemCount)")
        case .sourceRequest:
            signposter.endInterval("Map Source Request", state, "outcome=\(outcome, privacy: .public) count=\(itemCount)")
        case .transport:
            signposter.endInterval("ArcGIS Transport", state, "outcome=\(outcome, privacy: .public) bytes=\(itemCount)")
        case .decoding:
            signposter.endInterval("ArcGIS Decoding", state, "outcome=\(outcome, privacy: .public) bytes=\(itemCount)")
        case .mapping:
            signposter.endInterval("Pulse Item Mapping", state, "outcome=\(outcome, privacy: .public) count=\(itemCount)")
        case .merge:
            signposter.endInterval("Map Item Merge", state, "outcome=\(outcome, privacy: .public) count=\(itemCount)")
        case .cacheEncoding:
            signposter.endInterval("Map Cache Encoding", state, "outcome=\(outcome, privacy: .public) bytes=\(itemCount)")
        case .annotationDiff:
            signposter.endInterval("Map Annotation Diff", state, "outcome=\(outcome, privacy: .public) count=\(itemCount)")
        case .annotationApply:
            signposter.endInterval("Map Annotation Apply", state, "outcome=\(outcome, privacy: .public) count=\(itemCount)")
        }
    }

    nonisolated func milestone(
        _ milestone: MapPerformanceMilestone,
        context: MapPerformanceContext,
        itemCount: Int
    ) {
        let metadata = context.description
        switch milestone {
        case .appLaunch:
            signposter.emitEvent("App Launch Started", "\(metadata, privacy: .public) count=\(itemCount)")
        case .initialResults:
            signposter.emitEvent("Initial Nearby Results Ready", "\(metadata, privacy: .public) count=\(itemCount)")
        case .selectedRadiusSeedReused:
            signposter.emitEvent("Near You Results Reused", "\(metadata, privacy: .public) count=\(itemCount)")
        case .mapPresentation:
            signposter.emitEvent("Map Presentation Started", "\(metadata, privacy: .public) count=\(itemCount)")
        case .mapInteractive:
            signposter.emitEvent("Map Interactive", "\(metadata, privacy: .public) count=\(itemCount)")
        case .firstMarkers:
            signposter.emitEvent("First Map Markers", "\(metadata, privacy: .public) count=\(itemCount)")
        case .coveragePage:
            signposter.emitEvent("Map Coverage Page", "\(metadata, privacy: .public) count=\(itemCount)")
        case .closeInCoverage:
            signposter.emitEvent("Close-in Coverage Complete", "\(metadata, privacy: .public) count=\(itemCount)")
        case .selectedRadiusCoverage:
            signposter.emitEvent("Selected Radius Coverage Complete", "\(metadata, privacy: .public) count=\(itemCount)")
        case .boundedCoverage:
            signposter.emitEvent("Bounded Map Coverage Complete", "\(metadata, privacy: .public) count=\(itemCount)")
        case .clusteringStable:
            signposter.emitEvent("Map Clustering Stable", "\(metadata, privacy: .public) count=\(itemCount)")
        }
    }
}

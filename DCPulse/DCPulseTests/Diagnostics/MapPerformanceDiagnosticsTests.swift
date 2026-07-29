import Foundation
import Testing
@testable import DCPulse

@MainActor
struct MapPerformanceDiagnosticsTests {
    @Test func metadataContainsOnlyCoarseOperationalContext() throws {
        let endpoint = try #require(URL(
            string: "https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/ServiceRequests/FeatureServer/21"
        ))
        let context = MapPerformanceContext(
            source: MapPerformanceContext.endpoint(endpoint),
            pass: .closeIn,
            radiusMiles: 0.25,
            offset: 150,
            limit: 150
        )

        #expect(context.description == "source=dc311 pass=closeIn radius=0.25mi offset=150 limit=150")
        #expect(!context.description.contains("maps2.dcgis.dc.gov"))
        #expect(!context.description.contains("38."))
        #expect(!context.description.contains("-77."))
        #expect(!context.description.localizedCaseInsensitiveContains("address"))
        #expect(!context.description.localizedCaseInsensitiveContains("location"))
        #expect(!context.description.localizedCaseInsensitiveContains("identifier"))
    }

    @Test func contextOnlyAcceptsApprovedRadiusBuckets() {
        #expect(MapPerformanceContext(radiusMiles: 0.25).radiusBucket == "0.25mi")
        #expect(MapPerformanceContext(radiusMiles: 0.5).radiusBucket == "0.5mi")
        #expect(MapPerformanceContext(radiusMiles: 1).radiusBucket == "1mi")
        #expect(MapPerformanceContext(radiusMiles: 38.9072).radiusBucket == "other")
    }

    @Test func coverageInstrumentationReportsRepeatableStagesWithoutSearchLocation() async throws {
        let item = try #require(SampleData.items.first)
        let diagnostics = RecordingMapPerformanceDiagnostics()
        let store = PulseDataStore(
            repository: BaselineStubRepository(item: item),
            mapPerformanceDiagnostics: diagnostics
        )

        await store.load()
        await store.prepareMapResults()

        let snapshot = diagnostics.snapshot
        #expect(snapshot.startedStages.contains(.coverageSession))
        #expect(snapshot.startedStages.filter { $0 == .coveragePass }.count == 2)
        #expect(snapshot.startedStages.contains(.merge))
        #expect(snapshot.startedStages.contains(.cacheEncoding))
        #expect(snapshot.milestones.contains(.coveragePage))
        #expect(snapshot.milestones.contains(.closeInCoverage))
        #expect(snapshot.milestones.contains(.selectedRadiusCoverage))
        #expect(snapshot.milestones.contains(.boundedCoverage))
        #expect(snapshot.contexts.allSatisfy { !$0.contains("38.") && !$0.contains("-77.") })
        #expect(snapshot.contexts.allSatisfy { !$0.localizedCaseInsensitiveContains("Downtown") })
    }

    @Test func renderMilestonesResetForEachMapContextAndTrackItemIdentity() throws {
        let firstCoordinate = try #require(PulseItem.Coordinate(latitude: 38.90, longitude: -77.03))
        let secondCoordinate = try #require(PulseItem.Coordinate(latitude: 38.91, longitude: -77.04))
        let firstContext = MapRenderingContext(
            searchCoordinate: firstCoordinate,
            radiusMiles: 0.5,
            queryDays: 30
        )
        let secondContext = MapRenderingContext(
            searchCoordinate: secondCoordinate,
            radiusMiles: 0.5,
            queryDays: 30
        )
        let firstID = PulseItem.ID(source: .serviceRequests311, sourceIdentifier: "first")
        let secondID = PulseItem.ID(source: .serviceRequests311, sourceIdentifier: "second")
        var tracker = MapRenderMilestoneTracker()

        tracker.update(context: firstContext)
        let firstMarkers = tracker.shouldReportFirstMarkers()
        let duplicateFirstMarkers = tracker.shouldReportFirstMarkers()
        let firstStableRender = tracker.shouldReportStableRender(itemIDs: [firstID])
        let duplicateStableRender = tracker.shouldReportStableRender(itemIDs: [firstID])
        let sameCountNewItemsRender = tracker.shouldReportStableRender(itemIDs: [secondID])
        #expect(firstMarkers)
        #expect(!duplicateFirstMarkers)
        #expect(firstStableRender)
        #expect(!duplicateStableRender)
        #expect(sameCountNewItemsRender)

        tracker.update(context: secondContext)
        let nextContextFirstMarkers = tracker.shouldReportFirstMarkers()
        let nextContextStableRender = tracker.shouldReportStableRender(itemIDs: [secondID])
        #expect(nextContextFirstMarkers)
        #expect(nextContextStableRender)
    }
}

private struct BaselineStubRepository: PulseRepositoryProtocol {
    let item: PulseItem

    func nearbyItems(
        coordinate: PulseItem.Coordinate,
        radiusMiles: Double,
        days: Int,
        offset: Int,
        limit: Int
    ) async throws -> PulsePage {
        PulsePage(items: [item], nextOffset: offset + 1, hasMore: false)
    }
}

private final class RecordingMapPerformanceDiagnostics: MapPerformanceDiagnosticsProtocol, @unchecked Sendable {
    struct Snapshot {
        let startedStages: [MapPerformanceStage]
        let milestones: [MapPerformanceMilestone]
        let contexts: [String]
    }

    private let lock = NSLock()
    private var startedStages: [MapPerformanceStage] = []
    private var recordedMilestones: [MapPerformanceMilestone] = []
    private var contexts: [String] = []

    nonisolated func begin(
        _ stage: MapPerformanceStage,
        context: MapPerformanceContext
    ) -> MapPerformanceInterval {
        lock.withLock {
            startedStages.append(stage)
            contexts.append(context.description)
        }
        return MapPerformanceInterval(stage: stage, state: nil)
    }

    nonisolated func end(
        _ interval: MapPerformanceInterval,
        outcome: MapPerformanceOutcome,
        itemCount: Int
    ) {}

    nonisolated func milestone(
        _ milestone: MapPerformanceMilestone,
        context: MapPerformanceContext,
        itemCount: Int
    ) {
        lock.withLock {
            recordedMilestones.append(milestone)
            contexts.append(context.description)
        }
    }

    nonisolated var snapshot: Snapshot {
        lock.withLock {
            Snapshot(
                startedStages: startedStages,
                milestones: recordedMilestones,
                contexts: contexts
            )
        }
    }
}

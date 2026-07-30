import Foundation
import Testing
@testable import DCPulse

struct MapItemPipelineTests {
    @Test func tracesEveryRecordFromInputToAnnotationWithoutIdentifiersInTheSummary() throws {
        let annotation = try #require(SampleData.items.first)
        let wrongStatus = replacing(annotation, id: "status", status: .resolved)
        let wrongSource = replacing(
            annotation,
            id: "source",
            source: .buildingPermits2026
        )
        let wrongCategory = replacing(annotation, id: "category", category: "Other")
        let missingCoordinate = replacing(annotation, id: "coordinate", coordinate: nil)

        let pipeline = MapItemPipeline(
            items: [
                annotation,
                annotation,
                wrongStatus,
                wrongSource,
                wrongCategory,
                missingCoordinate
            ],
            selectedSources: [.serviceRequests311],
            status: .active,
            category: annotation.category
        )

        #expect(pipeline.trace == .init(
            received: 6,
            unique: 5,
            filteredBySource: 1,
            filteredByStatus: 1,
            filteredByCategory: 1,
            missingCoordinate: 1,
            annotations: 1
        ))
        #expect(pipeline.annotationItems == [annotation])
        #expect(pipeline.disposition(of: annotation.id) == .annotation)
        #expect(pipeline.disposition(of: wrongStatus.id) == .filteredByStatus)
        #expect(pipeline.disposition(of: wrongSource.id) == .filteredBySource)
        #expect(pipeline.disposition(of: wrongCategory.id) == .filteredByCategory)
        #expect(pipeline.disposition(of: missingCoordinate.id) == .missingCoordinate)
    }

    @Test func reportsRecordsThatNeverReachedTheMapPipeline() {
        let pipeline = MapItemPipeline(items: [])
        let missingID = PulseItem.ID(
            source: .serviceRequests311,
            sourceIdentifier: "not-received"
        )

        #expect(pipeline.disposition(of: missingID) == .notReceived)
    }

    private func replacing(
        _ item: PulseItem,
        id: String,
        source: PulseItem.Source = .serviceRequests311,
        category: String? = nil,
        status: PulseItem.Status = .active,
        coordinate: PulseItem.Coordinate? = SampleData.center
    ) -> PulseItem {
        PulseItem(
            id: .init(source: source, sourceIdentifier: id),
            category: category ?? item.category,
            subtype: item.subtype,
            title: item.title,
            summary: item.summary,
            status: status,
            openedAt: item.openedAt,
            updatedAt: item.updatedAt,
            closedAt: item.closedAt,
            coordinate: coordinate,
            address: item.address,
            wardOrNeighborhood: item.wardOrNeighborhood,
            responsibleAgency: item.responsibleAgency,
            sourceAttributes: item.sourceAttributes,
            sourceURL: item.sourceURL
        )
    }
}

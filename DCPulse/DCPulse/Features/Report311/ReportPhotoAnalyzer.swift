import Foundation
import Vision

struct ReportImageAnalysis: Equatable, Sendable {
    let classifications: [String]
    let suggestedCategory: Report311Draft.Category
}

protocol ReportPhotoAnalyzing: Sendable {
    func analyze(_ data: Data) async throws -> ReportImageAnalysis
}

actor VisionReportPhotoAnalyzer: ReportPhotoAnalyzing {
    nonisolated init() {}

    func analyze(_ data: Data) async throws -> ReportImageAnalysis {
        try Task.checkCancellation()
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(data: data, options: [:])
        try handler.perform([request])
        try Task.checkCancellation()

        let classifications = (request.results ?? [])
            .filter { $0.confidence >= 0.08 }
            .prefix(12)
            .map(\.identifier)
        return ReportImageAnalysis(
            classifications: classifications,
            suggestedCategory: ReportSuggestionEngine.category(for: classifications)
        )
    }
}

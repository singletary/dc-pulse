import Foundation
import Testing
@testable import DCPulse

@MainActor
struct Report311ViewModelTests {
    @Test func failedReplacementKeepsTheExistingPhotoAndDraft() async {
        let viewModel = Report311ViewModel(analyzer: ImmediatePhotoAnalyzer())
        viewModel.draft.details = "Keep these details"
        await viewModel.setPhoto(Data([1]))
        let originalImage = viewModel.imageData

        let sequence = viewModel.beginPhotoSelection()
        viewModel.photoSelectionFailed(selectionSequence: sequence)

        #expect(viewModel.imageData == originalImage)
        #expect(viewModel.draft.details == "Keep these details")
        #expect(viewModel.photoSelectionError == "That photo could not be loaded. Your existing draft and photo are unchanged.")
    }

    @Test func aLaterSelectionWinsWhenTheFirstAnalysisFinishesLast() async {
        let analyzer = ControlledPhotoAnalyzer()
        let viewModel = Report311ViewModel(analyzer: analyzer)
        let first = viewModel.beginPhotoSelection()
        let firstTask = Task { await viewModel.setPhoto(Data([1]), selectionSequence: first) }
        await analyzer.waitUntilStarted(for: 1)

        let second = viewModel.beginPhotoSelection()
        let secondTask = Task { await viewModel.setPhoto(Data([2]), selectionSequence: second) }
        await analyzer.waitUntilStarted(for: 2)
        await analyzer.finish(2, category: .pothole)
        await secondTask.value
        await analyzer.finish(1, category: .graffitiRemoval)
        await firstTask.value

        #expect(viewModel.imageData == Data([2]))
        #expect(viewModel.draft.category == .pothole)
        #expect(viewModel.analysisState == .analyzed)
    }

    @Test func reselectingTheSamePhotoStartsANewAttempt() async {
        let analyzer = ControlledPhotoAnalyzer()
        let viewModel = Report311ViewModel(analyzer: analyzer)

        let first = viewModel.beginPhotoSelection()
        viewModel.photoSelectionFailed(selectionSequence: first)
        let second = viewModel.beginPhotoSelection()
        let task = Task { await viewModel.setPhoto(Data([3]), selectionSequence: second) }
        await analyzer.waitUntilStarted(for: 3)
        await analyzer.finish(3, category: .streetlightRepair)
        await task.value

        #expect(second > first)
        #expect(viewModel.photoSelectionError == nil)
        #expect(viewModel.imageData == Data([3]))
        #expect(viewModel.draft.category == .streetlightRepair)
    }

    @Test func removingAPhotoPreservesTheDraftAndRejectsLateAnalysis() async {
        let analyzer = ControlledPhotoAnalyzer()
        let viewModel = Report311ViewModel(analyzer: analyzer)
        viewModel.draft.details = "Keep this description"
        let sequence = viewModel.beginPhotoSelection()
        let task = Task { await viewModel.setPhoto(Data([4]), selectionSequence: sequence) }
        await analyzer.waitUntilStarted(for: 4)

        viewModel.removePhoto()
        await analyzer.finish(4, category: .graffitiRemoval)
        await task.value

        #expect(viewModel.imageData == nil)
        #expect(viewModel.analysisState == .idle)
        #expect(viewModel.photoSelectionError == nil)
        #expect(viewModel.draft.details == "Keep this description")
        #expect(viewModel.draft.category == .other)
    }
}

private struct ImmediatePhotoAnalyzer: ReportPhotoAnalyzing {
    func analyze(_ data: Data) async throws -> ReportImageAnalysis {
        ReportImageAnalysis(classifications: [], suggestedCategory: .other)
    }
}

private actor ControlledPhotoAnalyzer: ReportPhotoAnalyzing {
    private var continuations: [UInt8: CheckedContinuation<ReportImageAnalysis, Never>] = [:]
    private var started: Set<UInt8> = []

    func analyze(_ data: Data) async throws -> ReportImageAnalysis {
        let key = data.first!
        started.insert(key)
        return await withCheckedContinuation { continuation in
            continuations[key] = continuation
        }
    }

    func waitUntilStarted(for key: UInt8) async {
        while !started.contains(key) {
            await Task.yield()
        }
    }

    func finish(_ key: UInt8, category: Report311Draft.Category) {
        continuations.removeValue(forKey: key)?.resume(
            returning: ReportImageAnalysis(classifications: [], suggestedCategory: category)
        )
    }
}

import Foundation
import Observation

enum DC311Handoff {
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/dc311/id966327559")!
    static let websiteURL = URL(string: "https://311.dc.gov/citizen/s/")!
}

@MainActor @Observable
final class Report311ViewModel {
    enum AnalysisState: Equatable {
        case idle
        case analyzing
        case analyzed
        case failed
    }

    var draft = Report311Draft()
    private(set) var imageData: Data?
    private(set) var analysisState: AnalysisState = .idle
    private(set) var photoSelectionError: String?
    private let analyzer: any ReportPhotoAnalyzing
    private var photoSelectionSequence = 0

    init(analyzer: (any ReportPhotoAnalyzing)? = nil) {
        self.analyzer = analyzer ?? VisionReportPhotoAnalyzer()
    }

    func setPhoto(_ data: Data) async {
        let selectionSequence = beginPhotoSelection()
        await setPhoto(data, selectionSequence: selectionSequence)
    }

    @discardableResult
    func beginPhotoSelection() -> Int {
        photoSelectionSequence += 1
        photoSelectionError = nil
        return photoSelectionSequence
    }

    func setPhoto(_ data: Data, selectionSequence: Int) async {
        guard selectionSequence == photoSelectionSequence else { return }
        imageData = data
        analysisState = .analyzing
        do {
            let analysis = try await analyzer.analyze(data)
            guard selectionSequence == photoSelectionSequence else { return }
            if draft.category == .other, analysis.suggestedCategory != .other {
                draft.category = analysis.suggestedCategory
            }
            analysisState = .analyzed
        } catch is CancellationError {
            guard selectionSequence == photoSelectionSequence else { return }
            analysisState = .idle
        } catch {
            guard selectionSequence == photoSelectionSequence else { return }
            analysisState = .failed
        }
    }

    func photoSelectionFailed(selectionSequence: Int) {
        guard selectionSequence == photoSelectionSequence else { return }
        photoSelectionError = "That photo could not be loaded. Your existing draft and photo are unchanged."
    }

    func useCurrentLocation(_ coordinate: PulseItem.Coordinate?, address: String?) {
        guard let coordinate else { return }
        draft.coordinate = coordinate
        if let address { draft.address = address.replacingOccurrences(of: "Near ", with: "") }
    }
}

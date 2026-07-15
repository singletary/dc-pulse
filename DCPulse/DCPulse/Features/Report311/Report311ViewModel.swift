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
    private let analyzer: any ReportPhotoAnalyzing

    init(analyzer: (any ReportPhotoAnalyzing)? = nil) {
        self.analyzer = analyzer ?? VisionReportPhotoAnalyzer()
    }

    func setPhoto(_ data: Data) async {
        imageData = data
        analysisState = .analyzing
        do {
            let analysis = try await analyzer.analyze(data)
            if draft.category == .other, analysis.suggestedCategory != .other {
                draft.category = analysis.suggestedCategory
            }
            analysisState = .analyzed
        } catch is CancellationError {
            analysisState = .idle
        } catch {
            analysisState = .failed
        }
    }

    func useCurrentLocation(_ coordinate: PulseItem.Coordinate?, address: String?) {
        guard let coordinate else { return }
        draft.coordinate = coordinate
        if let address { draft.address = address.replacingOccurrences(of: "Near ", with: "") }
    }
}

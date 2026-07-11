import Foundation

protocol ArcGISClientProtocol: Sendable {
    func fetchPage(from layerURL: URL, query: ArcGISQuery) async throws -> ArcGISFeaturePage
}

enum ArcGISClientError: Error, Equatable {
    case invalidRequest
    case transport(String)
    case httpStatus(Int)
    case server(ArcGISServerError)
    case decoding(String)
}

struct URLSessionArcGISClient: ArcGISClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func fetchPage(from layerURL: URL, query: ArcGISQuery) async throws -> ArcGISFeaturePage {
        let url = try query.url(for: layerURL)
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(from: url) }
        catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw ArcGISClientError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw ArcGISClientError.transport("Non-HTTP response") }
        guard (200..<300).contains(http.statusCode) else { throw ArcGISClientError.httpStatus(http.statusCode) }
        if let envelope = try? decoder.decode(ArcGISErrorEnvelope.self, from: data) {
            throw ArcGISClientError.server(envelope.error)
        }
        do { return try decoder.decode(ArcGISFeaturePage.self, from: data) }
        catch { throw ArcGISClientError.decoding(error.localizedDescription) }
    }
}

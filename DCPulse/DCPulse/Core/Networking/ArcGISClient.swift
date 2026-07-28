import Foundation

protocol ArcGISClientProtocol: Sendable {
    func fetchPage(from layerURL: URL, query: ArcGISQuery) async throws -> ArcGISFeaturePage
}

protocol ArcGISCountClientProtocol: Sendable {
    func fetchCount(from layerURL: URL, query: ArcGISQuery) async throws -> Int
}

enum ArcGISClientError: Error, Equatable {
    case invalidRequest
    case transport(String)
    case httpStatus(Int)
    case server(ArcGISServerError)
    case decoding(String)
}

struct URLSessionArcGISClient: ArcGISClientProtocol, ArcGISCountClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let diagnostics: any MapPerformanceDiagnosticsProtocol

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        diagnostics: any MapPerformanceDiagnosticsProtocol = MapPerformanceDiagnostics.shared
    ) {
        self.session = session
        self.decoder = decoder
        self.diagnostics = diagnostics
    }

    func fetchPage(from layerURL: URL, query: ArcGISQuery) async throws -> ArcGISFeaturePage {
        try await fetch(ArcGISFeaturePage.self, from: layerURL, query: query)
    }

    func fetchCount(from layerURL: URL, query: ArcGISQuery) async throws -> Int {
        try await fetch(ArcGISCountResponse.self, from: layerURL, query: query).count
    }

    private func fetch<Response: Decodable>(_ type: Response.Type, from layerURL: URL, query: ArcGISQuery) async throws -> Response {
        let url = try query.url(for: layerURL)
        let context = MapPerformanceContext(
            source: MapPerformanceContext.endpoint(layerURL),
            radiusMiles: query.radiusMiles,
            offset: query.resultOffset ?? 0,
            limit: query.resultRecordCount ?? 0
        )
        let data: Data
        let response: URLResponse
        let transportInterval = diagnostics.begin(.transport, context: context)
        do {
            (data, response) = try await session.data(from: url)
            diagnostics.end(transportInterval, outcome: .succeeded, itemCount: data.count)
        }
        catch {
            diagnostics.end(
                transportInterval,
                outcome: Task.isCancelled || (error as? URLError)?.code == .cancelled ? .cancelled : .failed,
                itemCount: 0
            )
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw ArcGISClientError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw ArcGISClientError.transport("Non-HTTP response") }
        guard (200..<300).contains(http.statusCode) else { throw ArcGISClientError.httpStatus(http.statusCode) }
        let decodingInterval = diagnostics.begin(.decoding, context: context)
        do {
            if let envelope = try? decoder.decode(ArcGISErrorEnvelope.self, from: data) {
                diagnostics.end(decodingInterval, outcome: .failed, itemCount: data.count)
                throw ArcGISClientError.server(envelope.error)
            }
            let decoded = try decoder.decode(Response.self, from: data)
            diagnostics.end(decodingInterval, outcome: .succeeded, itemCount: data.count)
            return decoded
        } catch let error as ArcGISClientError {
            throw error
        } catch {
            diagnostics.end(decodingInterval, outcome: .failed, itemCount: data.count)
            throw ArcGISClientError.decoding(error.localizedDescription)
        }
    }
}

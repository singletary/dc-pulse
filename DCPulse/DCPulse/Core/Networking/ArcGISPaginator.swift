import Foundation

struct ArcGISPaginator: Sendable {
    let client: any ArcGISClientProtocol

    func fetchAll(from layerURL: URL, query: ArcGISQuery) async throws -> [ArcGISFeature] {
        var query = query
        var results: [ArcGISFeature] = []
        var offset = query.resultOffset ?? 0
        repeat {
            try Task.checkCancellation()
            query.resultOffset = offset
            let page = try await client.fetchPage(from: layerURL, query: query)
            results.append(contentsOf: page.features)
            guard page.exceededTransferLimit else { return results }
            guard !page.features.isEmpty else { throw ArcGISClientError.decoding("Transfer limit exceeded with an empty page") }
            offset += page.features.count
        } while true
    }
}

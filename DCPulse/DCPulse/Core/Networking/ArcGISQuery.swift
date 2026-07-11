import Foundation

struct ArcGISQuery: Equatable, Sendable {
    struct Point: Equatable, Sendable {
        let longitude: Double
        let latitude: Double
    }

    var whereClause = "1=1"
    var outputFields = ["*"]
    var point: Point?
    var radiusMiles: Double?
    var returnGeometry = true
    var resultOffset: Int?
    var resultRecordCount: Int?
    var orderByFields: [String] = []

    func url(for layerURL: URL) throws -> URL {
        guard var components = URLComponents(url: layerURL.appendingPathComponent("query"), resolvingAgainstBaseURL: false) else {
            throw ArcGISClientError.invalidRequest
        }
        var items = [
            URLQueryItem(name: "where", value: whereClause),
            URLQueryItem(name: "outFields", value: outputFields.joined(separator: ",")),
            URLQueryItem(name: "returnGeometry", value: returnGeometry ? "true" : "false"),
            URLQueryItem(name: "outSR", value: "4326")
        ]
        if let point {
            items += [
                URLQueryItem(name: "geometry", value: "\(point.longitude),\(point.latitude)"),
                URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
                URLQueryItem(name: "inSR", value: "4326"),
                URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects")
            ]
        }
        if let radiusMiles {
            guard point != nil, radiusMiles >= 0 else { throw ArcGISClientError.invalidRequest }
            items += [
                URLQueryItem(name: "distance", value: String(radiusMiles)),
                URLQueryItem(name: "units", value: "esriSRUnit_StatuteMile")
            ]
        }
        if let resultOffset { items.append(URLQueryItem(name: "resultOffset", value: String(resultOffset))) }
        if let resultRecordCount { items.append(URLQueryItem(name: "resultRecordCount", value: String(resultRecordCount))) }
        if !orderByFields.isEmpty { items.append(URLQueryItem(name: "orderByFields", value: orderByFields.joined(separator: ","))) }
        items.append(URLQueryItem(name: "f", value: "json"))
        components.queryItems = items
        guard let url = components.url else { throw ArcGISClientError.invalidRequest }
        return url
    }
}

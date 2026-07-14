import Foundation

struct ArcGISFeature: Decodable, Equatable, Sendable {
    struct Geometry: Decodable, Equatable, Sendable { let x: Double?; let y: Double? }
    let attributes: [String: JSONValue]
    let geometry: Geometry?
}

struct ArcGISFeaturePage: Decodable, Equatable, Sendable {
    let objectIdFieldName: String?
    let exceededTransferLimit: Bool
    let features: [ArcGISFeature]

    private enum CodingKeys: String, CodingKey { case objectIdFieldName, exceededTransferLimit, features }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objectIdFieldName = try container.decodeIfPresent(String.self, forKey: .objectIdFieldName)
        exceededTransferLimit = try container.decodeIfPresent(Bool.self, forKey: .exceededTransferLimit) ?? false
        features = try container.decodeIfPresent([ArcGISFeature].self, forKey: .features) ?? []
    }
}

struct ArcGISCountResponse: Decodable, Equatable, Sendable {
    let count: Int
}

struct ArcGISServerError: Decodable, Error, Equatable, Sendable {
    let code: Int
    let message: String
    let details: [String]

    private enum CodingKeys: String, CodingKey { case code, message, details }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        details = try container.decodeIfPresent([String].self, forKey: .details) ?? []
    }
}

struct ArcGISErrorEnvelope: Decodable { let error: ArcGISServerError }

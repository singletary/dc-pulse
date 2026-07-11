import Foundation

protocol PulseItemMapping: Sendable {
    associatedtype SourceRecord: Sendable
    func map(_ record: SourceRecord) throws -> PulseItem
}

enum PulseItemMappingError: Error, Equatable {
    case missingStableIdentifier
    case missingRequiredField(String)
    case malformedField(String)
}

enum SourceDateParser {
    static func date(from value: JSONValue?) -> Date? {
        switch value {
        case .number(let milliseconds): Date(timeIntervalSince1970: milliseconds / 1_000)
        case .string(let text): ISO8601DateFormatter().date(from: text)
        default: nil
        }
    }
}

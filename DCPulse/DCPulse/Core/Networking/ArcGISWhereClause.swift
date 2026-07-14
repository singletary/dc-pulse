import Foundation

enum ArcGISWhereClause {
    static func quotedList(_ values: [String]) -> String {
        values.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }
            .joined(separator: ",")
    }
}

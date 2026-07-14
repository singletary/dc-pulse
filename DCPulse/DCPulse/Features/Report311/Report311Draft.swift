import Foundation

struct Report311Draft: Equatable, Sendable {
    enum Category: String, CaseIterable, Identifiable, Sendable {
        case graffitiRemoval
        case pothole
        case illegalDumping
        case trashCollection
        case rodentControl
        case treeService
        case streetlightRepair
        case abandonedVehicle
        case sidewalkRepair
        case other

        var id: Self { self }

        var displayName: String {
            switch self {
            case .graffitiRemoval: "Graffiti removal"
            case .pothole: "Pothole"
            case .illegalDumping: "Illegal dumping"
            case .trashCollection: "Trash collection"
            case .rodentControl: "Rodent control"
            case .treeService: "Tree service"
            case .streetlightRepair: "Streetlight repair"
            case .abandonedVehicle: "Abandoned vehicle"
            case .sidewalkRepair: "Sidewalk repair"
            case .other: "Other service request"
            }
        }

        var systemImage: String {
            switch self {
            case .graffitiRemoval: "paintbrush.pointed"
            case .pothole: "road.lanes"
            case .illegalDumping, .trashCollection: "trash"
            case .rodentControl: "pawprint"
            case .treeService: "tree"
            case .streetlightRepair: "lightbulb"
            case .abandonedVehicle: "car"
            case .sidewalkRepair: "figure.walk"
            case .other: "ellipsis.circle"
            }
        }
    }

    var category: Category = .other
    var details = ""
    var address = ""
    var coordinate: PulseItem.Coordinate?

    var summaryForOfficialPortal: String {
        var lines = ["Suggested DC 311 category: \(category.displayName)"]
        if !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Details: \(details.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Location: \(address.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return lines.joined(separator: "\n")
    }
}

enum ReportSuggestionEngine {
    nonisolated static func category(for classifications: [String]) -> Report311Draft.Category {
        let labels = classifications.joined(separator: " ").lowercased()
        let mappings: [(Report311Draft.Category, [String])] = [
            (.graffitiRemoval, ["graffiti", "spray paint", "mural"]),
            (.pothole, ["pothole", "asphalt", "road surface", "pavement"]),
            (.illegalDumping, ["dump", "debris", "rubble", "discarded furniture"]),
            (.trashCollection, ["trash", "garbage", "refuse", "waste container", "dumpster"]),
            (.rodentControl, ["rat", "mouse", "rodent"]),
            (.treeService, ["fallen tree", "tree branch", "stump"]),
            (.streetlightRepair, ["streetlight", "lamp post", "lamppost"]),
            (.abandonedVehicle, ["abandoned car", "wrecked car", "vehicle"]),
            (.sidewalkRepair, ["sidewalk", "curb", "concrete pavement"])
        ]

        return mappings.first { _, keywords in
            keywords.contains { labels.contains($0) }
        }?.0 ?? .other
    }
}

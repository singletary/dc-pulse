import Foundation

enum PulseCategoryVisual {
    static func emoji(for category: String) -> String {
        let value = category.lowercased()
        if value.contains("rodent") || value.contains("rat") { return "🐀" }
        if value.contains("trash") || value.contains("dump") || value.contains("collection") { return "🗑️" }
        if value.contains("graffiti") { return "🎨" }
        if value.contains("light") { return "💡" }
        if value.contains("tree") { return "🌳" }
        if value.contains("pothole") || value.contains("street") { return "🚧" }
        if value.contains("ddot") || value.contains("construction") { return "🚧" }
        if value.contains("building") || value.contains("permit") { return "🏗️" }
        return "📍"
    }
}

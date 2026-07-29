import Foundation

enum PulseCategoryVisual {
    static func emoji(for category: String) -> String {
        let value = category.lowercased()
        if value.contains("rodent") || value.contains("rat") { return "🐀" }
        if value.contains("trash") || value.contains("dump") || value.contains("collection") { return "🗑️" }
        if value.contains("graffiti") { return "🎨" }
        if value.contains("traffic") || value.contains("signal") || value.contains("crosswalk") ||
            value.contains("pedestrian") { return "🚦" }
        if value.contains("parking") || value.contains("vehicle") { return "🚗" }
        if value.contains("sidewalk") { return "🚶" }
        if value.contains("water") || value.contains("sewer") || value.contains("hydrant") { return "💧" }
        if value.contains("snow") || value.contains("ice") { return "❄️" }
        if value.contains("animal") { return "🐾" }
        if value.contains("noise") { return "🔊" }
        if value.contains("light") { return "💡" }
        if value.contains("tree") { return "🌳" }
        if value.contains("pothole") || value.contains("street") { return "🚧" }
        if value.contains("ddot") || value.contains("construction") { return "🚧" }
        if value.contains("building") || value.contains("permit") { return "🏗️" }
        return "📍"
    }
}

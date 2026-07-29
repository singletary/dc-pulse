import Testing
@testable import DCPulse

struct PulseCategoryVisualTests {
    @Test("Request categories use stable shared symbols", arguments: [
        ("DC Health Rodent & Vector Control", "🐀"),
        ("Illegal Dumping", "🗑️"),
        ("Graffiti Removal", "🎨"),
        ("Tree Inspection", "🌳"),
        ("Streetlight Repair", "💡"),
        ("Traffic Safety Input", "🚦"),
        ("Traffic Lights and Pedestrian Walk Signals", "🚦"),
        ("Parking Meter Repair", "🚗"),
        ("Water Leak", "💧"),
        ("DDOT Construction Permit", "🚧"),
        ("Building Permit", "🏗️"),
        ("Unmapped Request Type", "📍")
    ])
    func categorySymbol(category: String, expected: String) {
        #expect(PulseCategoryVisual.emoji(for: category) == expected)
    }
}

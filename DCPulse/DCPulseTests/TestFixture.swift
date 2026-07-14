import Foundation

enum TestFixture {
    static func data(named name: String) throws -> Data {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fixture = tests.deletingLastPathComponent().appending(path: "DCPulse/Resources/Fixtures/\(name).json")
        return try Data(contentsOf: fixture)
    }
}

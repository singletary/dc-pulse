import Foundation

enum TestFixture {
    private final class BundleToken: NSObject {}

    static func data(named name: String) throws -> Data {
        guard let fixture = Bundle(for: BundleToken.self).url(
            forResource: name,
            withExtension: "json"
        ) else {
            throw CocoaError(
                .fileNoSuchFile,
                userInfo: [NSFilePathErrorKey: "\(name).json"]
            )
        }

        return try Data(contentsOf: fixture)
    }
}

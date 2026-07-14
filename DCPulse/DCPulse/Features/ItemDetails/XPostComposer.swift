import Foundation

enum XPostComposer {
    static func nativeComposeURL(message: String) -> URL? {
        var components = URLComponents(string: "twitter://post")
        components?.queryItems = [URLQueryItem(name: "message", value: message)]
        return components?.url
    }

    static func composeURL(message: String) -> URL? {
        var components = URLComponents(string: "https://x.com/intent/post")
        components?.queryItems = [URLQueryItem(name: "text", value: message)]
        return components?.url
    }
}

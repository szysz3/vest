import Foundation

public struct APIConfiguration: Sendable {
    public let baseURL: String

    public static let shared: APIConfiguration = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let baseURL = plist["BaseURL"] as? String else {
            assertionFailure("Config.plist is missing or does not contain a valid BaseURL. Copy Config.plist.example to Config.plist.")
            return APIConfiguration(baseURL: "https://api.example.com")
        }
        return APIConfiguration(baseURL: baseURL)
    }()

    public init(baseURL: String) {
        self.baseURL = baseURL
    }
}

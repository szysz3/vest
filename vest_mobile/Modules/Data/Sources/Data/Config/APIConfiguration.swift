import Foundation

public struct APIConfiguration: Sendable {
    public let baseURL: String

    public static let shared: APIConfiguration = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let baseURL = json["BaseURL"] as? String else {
            assertionFailure("Config.json is missing or does not contain a valid BaseURL. Copy Config.json.example to App/Resources/Config.json so it is bundled.")
            return APIConfiguration(baseURL: "https://api.example.com")
        }
        return APIConfiguration(baseURL: baseURL)
    }()

    public init(baseURL: String) {
        self.baseURL = baseURL
    }
}

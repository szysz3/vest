import Foundation
import Testing
@testable import Data

@Test func apiConfigurationDefaultBaseURL() {
    let config = APIConfiguration(baseURL: "https://api.example.com")
    #expect(config.baseURL == "https://api.example.com")
}

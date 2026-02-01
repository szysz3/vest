import Foundation
import Domain

public enum HTTPMethod: String, Sendable {
    case GET, POST, PUT, DELETE
}

public struct HTTPClient: Sendable {
    public let session: URLSession
    public let apiConfiguration: APIConfiguration

    public init(apiConfiguration: APIConfiguration = .shared) {
        self.apiConfiguration = apiConfiguration

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public func request<T: Decodable & Sendable>(
        path: String,
        method: HTTPMethod = .GET,
        parameters: (any Encodable & Sendable)? = nil,
        queryParameters: [String: String]? = nil
    ) async throws -> T {
        let fullURL = apiConfiguration.baseURL + path
        guard var urlComponents = URLComponents(string: fullURL) else {
            throw DomainError.networkError("Invalid URL: \(fullURL)")
        }

        if let queryParameters {
            urlComponents.queryItems = queryParameters.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        guard let requestURL = urlComponents.url else {
            throw DomainError.networkError("Failed to construct URL")
        }

        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = method.rawValue

        if let parameters {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try Self.makeEncoder().encode(parameters)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DomainError.networkError("Invalid response")
        }

        if let error = HTTPClient.handleHTTPResponse(httpResponse) {
            throw error
        }

        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch let decodingError {
            assertionFailure("Decoding failed: \(decodingError)")
            throw DomainError.decodingError
        }
    }

    public static func handleError(_ error: Error) -> DomainError {
        if let domainError = error as? DomainError {
            return domainError
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .networkError(nsError.localizedDescription)
        }
        return .unknown(error.localizedDescription)
    }

    public static func handleHTTPResponse(_ response: HTTPURLResponse) -> DomainError? {
        switch response.statusCode {
        case 200...299:
            return nil
        case 401:
            return .unauthorized
        case 404:
            return .notFound
        case 500...599:
            return .serverError(response.statusCode)
        default:
            return .networkError("HTTP \(response.statusCode)")
        }
    }
}

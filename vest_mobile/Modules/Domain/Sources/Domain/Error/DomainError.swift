import Foundation

public enum DomainError: LocalizedError, Equatable, Sendable {
    case networkError(String)
    case decodingError
    case serverError(Int)
    case unauthorized
    case notFound
    case validationError(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message): return "Network error: \(message)"
        case .decodingError: return "Failed to decode response"
        case .serverError(let code): return "Server error: \(code)"
        case .unauthorized: return "Unauthorized"
        case .notFound: return "Resource not found"
        case .validationError(let message): return "Validation error: \(message)"
        case .unknown(let message): return message
        }
    }
}

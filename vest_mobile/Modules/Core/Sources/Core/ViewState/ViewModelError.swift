import Domain
import Foundation

public enum ViewModelError: LocalizedError, Equatable, Sendable {
    case serviceUnavailable
    case networkError(String)
    case decodingError
    case validationError(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable: return "Service is currently unavailable"
        case .networkError(let message): return "Network error: \(message)"
        case .decodingError: return "Failed to process data"
        case .validationError(let message): return message
        case .unknown(let message): return message
        }
    }

    public init(from error: Error) {
        if let viewModelError = error as? ViewModelError {
            self = viewModelError
        } else if let domainError = error as? DomainError {
            switch domainError {
            case .networkError(let message):
                self = .networkError(message)
            case .decodingError:
                self = .decodingError
            case .serverError, .unauthorized, .notFound:
                self = .serviceUnavailable
            case .validationError(let message):
                self = .validationError(message)
            case .unknown(let message):
                self = .unknown(message)
            }
        } else {
            self = .unknown(error.localizedDescription)
        }
    }
}

import Foundation

/// @mockable
public protocol GetPortfolioHistoryUseCaseProtocol: Sendable {
    func execute() async throws -> PortfolioHistory
}

public struct GetPortfolioHistoryUseCase: GetPortfolioHistoryUseCaseProtocol {
    private let repository: TransactionRepository

    public init(repository: TransactionRepository) {
        self.repository = repository
    }

    public func execute() async throws -> PortfolioHistory {
        try await repository.fetchPortfolioHistory()
    }
}

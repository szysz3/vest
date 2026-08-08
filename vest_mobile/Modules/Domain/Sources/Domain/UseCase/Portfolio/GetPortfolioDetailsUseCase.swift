import Foundation

/// @mockable
public protocol GetPortfolioDetailsUseCaseProtocol: Sendable {
    func execute() async throws -> [AssetDetail]
}

public struct GetPortfolioDetailsUseCase: GetPortfolioDetailsUseCaseProtocol {
    private let repository: TransactionRepository

    public init(repository: TransactionRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [AssetDetail] {
        try await repository.fetchPortfolioDetails()
    }
}

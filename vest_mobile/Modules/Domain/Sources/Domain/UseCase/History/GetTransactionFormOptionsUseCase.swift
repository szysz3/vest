import Foundation

/// @mockable
public protocol GetTransactionFormOptionsUseCaseProtocol: Sendable {
    func execute() async throws -> TransactionFormOptions
}

public struct GetTransactionFormOptionsUseCase: GetTransactionFormOptionsUseCaseProtocol {
    private let repository: TransactionRepository

    public init(repository: TransactionRepository) {
        self.repository = repository
    }

    public func execute() async throws -> TransactionFormOptions {
        try await repository.fetchTransactionFormOptions()
    }
}

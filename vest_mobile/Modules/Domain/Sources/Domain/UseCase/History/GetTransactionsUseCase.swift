import Foundation

/// @mockable
public protocol GetTransactionsUseCaseProtocol: Sendable {
    func execute() async throws -> [Transaction]
}

public struct GetTransactionsUseCase: GetTransactionsUseCaseProtocol {
    private let repository: TransactionRepository

    public init(repository: TransactionRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [Transaction] {
        try await repository.fetchTransactions()
    }
}

import Foundation

/// @mockable
public protocol AddTransactionUseCaseProtocol: Sendable {
    func execute(transaction: Transaction) async throws
    func execute(transactions: [Transaction]) async throws
}

public struct AddTransactionUseCase: AddTransactionUseCaseProtocol {
    private let repository: TransactionRepository

    public init(repository: TransactionRepository) {
        self.repository = repository
    }

    public func execute(transaction: Transaction) async throws {
        try await repository.addTransaction(transaction)
    }

    public func execute(transactions: [Transaction]) async throws {
        try await repository.addTransactions(transactions)
    }
}

import Foundation

/// @mockable
public protocol TransactionRepository: Sendable {
    func fetchTransactions() async throws -> [Transaction]
    func addTransaction(_ transaction: Transaction) async throws
    func addTransactions(_ transactions: [Transaction]) async throws
    func fetchTransactionFormOptions() async throws -> TransactionFormOptions
}

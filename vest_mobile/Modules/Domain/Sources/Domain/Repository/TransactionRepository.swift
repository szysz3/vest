import Foundation

/// @mockable
public protocol TransactionRepository: Sendable {
    func fetchTransactions() async throws -> [Transaction]
    func fetchPortfolioDetails() async throws -> [AssetDetail]
    func fetchStatementSyncStatus() async throws -> StatementSyncStatus
}

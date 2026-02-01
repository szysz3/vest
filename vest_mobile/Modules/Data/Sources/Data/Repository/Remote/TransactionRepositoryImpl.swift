import Domain
import Foundation

public struct TransactionRepositoryImpl: TransactionRepository {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchTransactions() async throws -> [Transaction] {
        try await httpClient.request(path: "/transactions")
    }

    public func addTransaction(_ transaction: Transaction) async throws {
        try await httpClient.requestVoid(
            path: "/transactions",
            method: .POST,
            parameters: transaction
        )
    }

    public func fetchTransactionFormOptions() async throws -> TransactionFormOptions {
        try await httpClient.request(path: "/transactions/form-options")
    }
}

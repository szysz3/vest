import Foundation

/// @mockable
public protocol GetStatementSyncStatusUseCaseProtocol: Sendable {
    func execute() async throws -> StatementSyncStatus
}

public struct GetStatementSyncStatusUseCase: GetStatementSyncStatusUseCaseProtocol {
    private let repository: TransactionRepository

    public init(repository: TransactionRepository) {
        self.repository = repository
    }

    public func execute() async throws -> StatementSyncStatus {
        try await repository.fetchStatementSyncStatus()
    }
}

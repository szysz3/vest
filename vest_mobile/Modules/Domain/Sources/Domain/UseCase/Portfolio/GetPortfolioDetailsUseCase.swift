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
        let transactions = try await repository.fetchTransactions()
        var holdings: [String: (assetType: AssetType, details: String, total: Double)] = [:]

        for transaction in transactions {
            guard !transaction.details.isEmpty else { continue }
            let key = "\(transaction.assetType.rawValue)_\(transaction.details)"
            var entry = holdings[key] ?? (assetType: transaction.assetType, details: transaction.details, total: 0)
            switch transaction.action {
            case .bought, .cashDeposit:
                entry.total += transaction.amount
            case .sold, .cashWithdrawal, .positionClosed:
                entry.total -= transaction.amount
            }
            holdings[key] = entry
        }

        return holdings.values
            .filter { $0.total > 0 }
            .map { AssetDetail(assetType: $0.assetType, details: $0.details, totalAmount: $0.total) }
            .sorted { ($0.assetType.rawValue, $0.details) < ($1.assetType.rawValue, $1.details) }
    }
}

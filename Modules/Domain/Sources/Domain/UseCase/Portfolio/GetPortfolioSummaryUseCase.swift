import Foundation

/// @mockable
public protocol GetPortfolioSummaryUseCaseProtocol: Sendable {
    func execute() async throws -> PortfolioSummary
}

public struct GetPortfolioSummaryUseCase: GetPortfolioSummaryUseCaseProtocol {
    private let repository: TransactionRepository

    public init(repository: TransactionRepository) {
        self.repository = repository
    }

    public func execute() async throws -> PortfolioSummary {
        let transactions = try await repository.fetchTransactions()
        let totals = transactions.reduce(into: [AssetType: Double]()) { result, transaction in
            let signedAmount = signedValue(for: transaction)
            result[transaction.assetType, default: 0] += signedAmount
        }

        let assets = totals
            .filter { $0.value > 0 }
            .map { PortfolioAsset(assetType: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }

        let totalAmount = assets.reduce(0) { $0 + $1.amount }
        return PortfolioSummary(totalAmount: totalAmount, assets: assets)
    }

    private func signedValue(for transaction: Transaction) -> Double {
        switch transaction.action {
        case .bought, .cashDeposit:
            return transaction.amount
        case .sold, .cashWithdrawal:
            return -transaction.amount
        }
    }
}

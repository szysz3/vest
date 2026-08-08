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
        let details = try await repository.fetchPortfolioDetails()
        var totals: [AssetType: Double] = [:]
        var totalNominalPLN: Double = 0
        var totalCurrentPLN: Double = 0
        var totalProfitPLN: Double = 0

        for item in details {
            let itemVal = item.nominalAmountPLN > 0 ? item.nominalAmountPLN : item.totalAmountPLN
            totals[item.assetType, default: 0] += itemVal
            totalNominalPLN += item.nominalAmountPLN
            totalCurrentPLN += item.totalAmountPLN
            totalProfitPLN += item.profitOrLossPLN
        }

        let assets = totals
            .filter { $0.value > 0 }
            .map { PortfolioAsset(assetType: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }

        let profitPct = totalNominalPLN > 0 ? (totalProfitPLN / totalNominalPLN * 100.0) : 0.0

        return PortfolioSummary(
            nominalAmount: totalNominalPLN,
            totalAmount: totalCurrentPLN,
            profitOrLoss: totalProfitPLN,
            profitOrLossPct: profitPct,
            assets: assets
        )
    }
}

import Foundation

public struct PortfolioSummary: Equatable, Sendable {
    public let totalAmount: Double
    public let assets: [PortfolioAsset]

    public init(totalAmount: Double, assets: [PortfolioAsset]) {
        self.totalAmount = totalAmount
        self.assets = assets
    }
}

public struct PortfolioAsset: Identifiable, Equatable, Sendable {
    public let id: AssetType
    public let assetType: AssetType
    public let amount: Double

    public init(assetType: AssetType, amount: Double) {
        self.id = assetType
        self.assetType = assetType
        self.amount = amount
    }
}

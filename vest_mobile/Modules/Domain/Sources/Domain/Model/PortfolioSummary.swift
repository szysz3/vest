import Foundation

public struct PortfolioSummary: Equatable, Sendable {
    public let nominalAmount: Double
    public let totalAmount: Double
    public let profitOrLoss: Double
    public let profitOrLossPct: Double
    public let assets: [PortfolioAsset]

    public init(
        nominalAmount: Double,
        totalAmount: Double,
        profitOrLoss: Double,
        profitOrLossPct: Double,
        assets: [PortfolioAsset]
    ) {
        self.nominalAmount = nominalAmount
        self.totalAmount = totalAmount
        self.profitOrLoss = profitOrLoss
        self.profitOrLossPct = profitOrLossPct
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

public struct AssetDetail: Identifiable, Equatable, Sendable {
    public let id: String
    public let assetType: AssetType
    public let details: String
    public let currency: String
    public let nominalAmount: Double
    public let totalAmount: Double
    public let profitOrLoss: Double
    public let profitOrLossPct: Double
    public let nominalAmountPLN: Double
    public let totalAmountPLN: Double
    public let profitOrLossPLN: Double
    public let accountNumber: String?

    public init(
        assetType: AssetType,
        details: String,
        currency: String,
        nominalAmount: Double,
        totalAmount: Double,
        profitOrLoss: Double,
        profitOrLossPct: Double,
        nominalAmountPLN: Double,
        totalAmountPLN: Double,
        profitOrLossPLN: Double,
        accountNumber: String? = nil
    ) {
        self.id = "\(assetType.rawValue)_\(details)_\(currency)"
        self.assetType = assetType
        self.details = details
        self.currency = currency
        self.nominalAmount = nominalAmount
        self.totalAmount = totalAmount
        self.profitOrLoss = profitOrLoss
        self.profitOrLossPct = profitOrLossPct
        self.nominalAmountPLN = nominalAmountPLN
        self.totalAmountPLN = totalAmountPLN
        self.profitOrLossPLN = profitOrLossPLN
        self.accountNumber = accountNumber
    }
}

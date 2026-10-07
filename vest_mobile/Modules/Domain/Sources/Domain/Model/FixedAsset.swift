import Foundation

public struct FixedAsset: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let assetType: AssetType
    public let details: String
    public let amount: Double
    public let currency: String
    public let amountPLN: Double

    public init(
        id: String,
        assetType: AssetType,
        details: String,
        amount: Double,
        currency: String,
        amountPLN: Double
    ) {
        self.id = id
        self.assetType = assetType
        self.details = details
        self.amount = amount
        self.currency = currency
        self.amountPLN = amountPLN
    }
}

public struct FixedAssetDraft: Equatable, Sendable, Codable {
    public let assetType: AssetType
    public let details: String
    public let amount: Double
    public let currency: String

    public init(
        assetType: AssetType,
        details: String,
        amount: Double,
        currency: String
    ) {
        self.assetType = assetType
        self.details = details
        self.amount = amount
        self.currency = currency
    }
}

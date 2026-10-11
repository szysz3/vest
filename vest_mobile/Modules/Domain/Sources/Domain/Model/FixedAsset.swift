import Foundation

public struct FixedAsset: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let assetType: AssetType
    public let details: String
    public let amount: Double
    public let currency: String
    public let amountPLN: Double
    public let weightOz: Double?

    public init(
        id: String,
        assetType: AssetType,
        details: String,
        amount: Double,
        currency: String,
        amountPLN: Double,
        weightOz: Double? = nil
    ) {
        self.id = id
        self.assetType = assetType
        self.details = details
        self.amount = amount
        self.currency = currency
        self.amountPLN = amountPLN
        self.weightOz = weightOz
    }
}

public struct FixedAssetDraft: Equatable, Sendable, Codable {
    public let assetType: AssetType
    public let details: String
    public let amount: Double
    public let currency: String
    public let weightOz: Double?

    public init(
        assetType: AssetType,
        details: String,
        amount: Double,
        currency: String,
        weightOz: Double? = nil
    ) {
        self.assetType = assetType
        self.details = details
        self.amount = amount
        self.currency = currency
        self.weightOz = weightOz
    }
}

import Foundation

public struct Transaction: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let amount: Double
    public let name: String
    public let action: TransactionAction
    public let assetType: AssetType
    public let place: String
    public let date: Date
    public let details: String
    public let profitOrLoss: Double?

    public init(
        id: UUID = UUID(),
        amount: Double,
        name: String,
        action: TransactionAction,
        assetType: AssetType,
        place: String,
        date: Date,
        details: String = "",
        profitOrLoss: Double? = nil
    ) {
        self.id = id
        self.amount = amount
        self.name = name
        self.action = action
        self.assetType = assetType
        self.place = place
        self.date = date
        self.details = details
        self.profitOrLoss = profitOrLoss
    }
}

public enum TransactionAction: String, CaseIterable, Sendable, Codable {
    case bought
    case sold
    case cashDeposit
    case cashWithdrawal
    case positionClosed
}

public enum AssetType: String, CaseIterable, Sendable, Codable {
    case bond
    case etf
    case stock
    case crypto
    case gold
    case cash
}

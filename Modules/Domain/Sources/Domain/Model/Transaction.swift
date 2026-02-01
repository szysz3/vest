import Foundation

public struct Transaction: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let amount: Double
    public let name: String
    public let action: TransactionAction
    public let assetType: AssetType
    public let place: String
    public let date: Date

    public init(
        id: UUID = UUID(),
        amount: Double,
        name: String,
        action: TransactionAction,
        assetType: AssetType,
        place: String,
        date: Date
    ) {
        self.id = id
        self.amount = amount
        self.name = name
        self.action = action
        self.assetType = assetType
        self.place = place
        self.date = date
    }
}

public enum TransactionAction: String, CaseIterable, Sendable {
    case bought
    case sold
    case cashDeposit
    case cashWithdrawal
}

public enum AssetType: String, CaseIterable, Sendable {
    case bond
    case etf
    case stock
    case crypto
    case gold
    case cash
}

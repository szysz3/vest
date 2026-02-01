import Foundation

public struct TransactionOperator: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct TransactionFormOptions: Equatable, Sendable {
    public let assetTypes: [AssetType]
    public let operators: [TransactionOperator]

    public init(assetTypes: [AssetType], operators: [TransactionOperator]) {
        self.assetTypes = assetTypes
        self.operators = operators
    }

    public static var empty: TransactionFormOptions {
        TransactionFormOptions(assetTypes: [], operators: [])
    }

    public var isEmpty: Bool {
        assetTypes.isEmpty || operators.isEmpty
    }
}

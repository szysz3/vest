import Foundation
import Core
import Domain

@MainActor
public final class PortfolioViewModel: ObservableObject {
    @Published private(set) var state: ViewState<PortfolioState, ViewModelError> = .idle
    @Published private(set) var formOptions: TransactionFormOptions = .empty
    private let getPortfolioSummaryUseCase: GetPortfolioSummaryUseCaseProtocol
    private let addTransactionUseCase: AddTransactionUseCaseProtocol
    private let getTransactionFormOptionsUseCase: GetTransactionFormOptionsUseCaseProtocol
    var onTransactionAdded: (@Sendable () async -> Void)?

    public nonisolated init(
        getPortfolioSummaryUseCase: GetPortfolioSummaryUseCaseProtocol,
        addTransactionUseCase: AddTransactionUseCaseProtocol,
        getTransactionFormOptionsUseCase: GetTransactionFormOptionsUseCaseProtocol
    ) {
        self.getPortfolioSummaryUseCase = getPortfolioSummaryUseCase
        self.addTransactionUseCase = addTransactionUseCase
        self.getTransactionFormOptionsUseCase = getTransactionFormOptionsUseCase
    }

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func loadFormOptionsIfNeeded() async {
        guard formOptions.isEmpty else { return }
        do {
            formOptions = try await getTransactionFormOptionsUseCase.execute()
        } catch {
            formOptions = .empty
        }
    }

    func load() async {
        state = .loading
        do {
            let summary = try await getPortfolioSummaryUseCase.execute()
            let assets = summary.assets.map { PortfolioState.Asset(domainAsset: $0) }
            state = .loaded(PortfolioState(totalAmount: summary.totalAmount, assets: assets))
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }

    func addTransaction(
        amount: Double,
        action: TransactionAction,
        assetType: AssetType,
        operatorName: String,
        details: String = "",
        profitOrLoss: Double? = nil
    ) async throws {
        if action.isCashAction && assetType != .cash {
            throw AddTransactionValidationError.cashActionRequiresCashAsset
        }
        if action == .bought && assetType != .cash {
            let summary = try await getPortfolioSummaryUseCase.execute()
            let cashBalance = summary.assets.first(where: { $0.assetType == .cash })?.amount ?? 0
            guard cashBalance >= amount else {
                throw AddTransactionValidationError.insufficientCash(available: cashBalance, required: amount)
            }
        }
        let name = details.isEmpty
            ? AssetDisplay.from(assetType: assetType).transactionName
            : details
        let transaction = Transaction(
            amount: amount,
            name: name,
            action: action,
            assetType: assetType,
            place: operatorName,
            date: .now,
            details: details,
            profitOrLoss: profitOrLoss
        )
        if action == .bought && assetType != .cash {
            let cashWithdrawal = Transaction(
                amount: amount,
                name: "Cash",
                action: .cashWithdrawal,
                assetType: .cash,
                place: operatorName,
                date: .now
            )
            try await addTransactionUseCase.execute(transactions: [transaction, cashWithdrawal])
        } else {
            try await addTransactionUseCase.execute(transaction: transaction)
        }
        await load()
        await onTransactionAdded?()
    }
}

private enum AddTransactionValidationError: LocalizedError {
    case cashActionRequiresCashAsset
    case insufficientCash(available: Double, required: Double)

    var errorDescription: String? {
        switch self {
        case .cashActionRequiresCashAsset:
            return "Cash deposits and withdrawals are only available for cash assets."
        case .insufficientCash(let available, let required):
            let availableFormatted = available.formatted(.currency(code: "PLN"))
            let requiredFormatted = required.formatted(.currency(code: "PLN"))
            return "Insufficient cash balance. Available: \(availableFormatted), required: \(requiredFormatted). Deposit cash first."
        }
    }
}

private extension TransactionAction {
    var isCashAction: Bool {
        switch self {
        case .cashDeposit, .cashWithdrawal:
            return true
        case .bought, .sold, .positionClosed:
            return false
        }
    }
}

public struct PortfolioState: Equatable, Sendable {
    public let totalAmount: Double
    public let assets: [Asset]

    public init(totalAmount: Double, assets: [Asset]) {
        self.totalAmount = totalAmount
        self.assets = assets
    }
}

public extension PortfolioState {
    struct Asset: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let amount: Double
        public let icon: String
        public let color: VestTone

        public init(
            id: UUID = UUID(),
            name: String,
            amount: Double,
            icon: String,
            color: VestTone
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.icon = icon
            self.color = color
        }

        public init(domainAsset: Domain.PortfolioAsset) {
            let display = AssetDisplay.from(assetType: domainAsset.assetType)
            self.init(
                id: UUID(),
                name: display.name,
                amount: domainAsset.amount,
                icon: display.icon,
                color: display.color
            )
        }
    }

}

private enum AssetDisplay {
    case bond
    case etf
    case stock
    case crypto
    case gold
    case cash

    var name: String {
        switch self {
        case .bond:
            return "Bond"
        case .etf:
            return "ETF"
        case .stock:
            return "Stock"
        case .crypto:
            return "Crypto"
        case .gold:
            return "Gold"
        case .cash:
            return "Cash"
        }
    }

    var transactionName: String {
        switch self {
        case .bond:
            return "Treasury Bond"
        case .etf:
            return "ETF"
        case .stock:
            return "Shares"
        case .crypto:
            return "Crypto"
        case .gold:
            return "Gold"
        case .cash:
            return "Cash"
        }
    }

    var icon: String {
        switch self {
        case .bond:
            return "doc.text.fill"
        case .etf:
            return "chart.line.uptrend.xyaxis"
        case .stock:
            return "building.columns.fill"
        case .crypto:
            return "bitcoinsign.circle.fill"
        case .gold:
            return "circle.hexagongrid.fill"
        case .cash:
            return "banknote.fill"
        }
    }

    var color: VestTone {
        switch self {
        case .bond:
            return .rose
        case .etf:
            return .ocean
        case .stock:
            return .electric
        case .crypto:
            return .violet
        case .gold:
            return .amber
        case .cash:
            return .sage
        }
    }

    static func from(assetType: AssetType) -> AssetDisplay {
        switch assetType {
        case .bond:
            return .bond
        case .etf:
            return .etf
        case .stock:
            return .stock
        case .crypto:
            return .crypto
        case .gold:
            return .gold
        case .cash:
            return .cash
        }
    }
}

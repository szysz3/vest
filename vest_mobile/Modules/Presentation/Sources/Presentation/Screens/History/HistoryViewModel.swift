import Foundation
import Core
import Domain

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published private(set) var state: ViewState<HistoryState, ViewModelError> = .idle
    private let getTransactionsUseCase: GetTransactionsUseCaseProtocol

    public nonisolated init(getTransactionsUseCase: GetTransactionsUseCaseProtocol) {
        self.getTransactionsUseCase = getTransactionsUseCase
    }

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            let transactions = try await getTransactionsUseCase.execute()
            let mapped = transactions.map(HistoryState.Transaction.init)
            state = .loaded(HistoryState(transactions: mapped))
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }
}

public struct HistoryState: Equatable, Sendable {
    public let transactions: [Transaction]

    public init(transactions: [Transaction]) {
        self.transactions = transactions
    }
}

public extension HistoryState {
    struct Transaction: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let amount: Double
        public let name: String
        public let action: Action
        public let assetType: AssetType
        public let place: String
        public let date: Date
        public let profitOrLoss: Double?

        public init(
            id: UUID = UUID(),
            amount: Double,
            name: String,
            action: Action,
            assetType: AssetType,
            place: String,
            date: Date,
            profitOrLoss: Double? = nil
        ) {
            self.id = id
            self.amount = amount
            self.name = name
            self.action = action
            self.assetType = assetType
            self.place = place
            self.date = date
            self.profitOrLoss = profitOrLoss
        }

        public init(_ transaction: Domain.Transaction) {
            self.init(
                id: transaction.id,
                amount: transaction.amount,
                name: transaction.name,
                action: Action(rawValue: transaction.action.rawValue) ?? .bought,
                assetType: AssetType(rawValue: transaction.assetType.rawValue) ?? .stock,
                place: transaction.place,
                date: transaction.date,
                profitOrLoss: transaction.profitOrLoss
            )
        }
    }

    enum Action: String, CaseIterable, Sendable {
        case bought
        case sold
        case cashDeposit
        case cashWithdrawal
        case positionClosed

        var title: String {
            switch self {
            case .bought:
                return "Bought"
            case .sold:
                return "Sold"
            case .cashDeposit:
                return "Cash Deposit"
            case .cashWithdrawal:
                return "Cash Withdrawal"
            case .positionClosed:
                return "Position Closed"
            }
        }

        var accentColor: VestTone { .mint }
    }

    enum AssetType: String, CaseIterable, Sendable {
        case bond
        case etf
        case stock
        case crypto
        case gold
        case cash

        var title: String {
            rawValue.uppercased()
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

        var tone: VestTone {
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
    }
}

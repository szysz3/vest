import Foundation
import Combine
import Core
import Domain

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published private(set) var state: ViewState<HistoryState, ViewModelError> = .idle
    @Published var filters = HistoryFilters()
    @Published var viewMode: HistoryViewMode = .all
    @Published private(set) var filteredResult = FilteredResult()

    private var isBound = false
    private let getTransactionsUseCase: GetTransactionsUseCaseProtocol

    public nonisolated init(getTransactionsUseCase: GetTransactionsUseCaseProtocol) {
        self.getTransactionsUseCase = getTransactionsUseCase
    }

    func bind() {
        guard !isBound else { return }
        isBound = true
        Publishers.CombineLatest3($state, $filters, $viewMode)
            .map { state, filters, viewMode in
                guard case .loaded(let historyState) = state else {
                    return FilteredResult()
                }
                return Self.computeFilteredResult(
                    transactions: historyState.transactions,
                    filters: filters,
                    viewMode: viewMode
                )
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$filteredResult)
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
            initializeFiltersIfNeeded()
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }

    var displayTransactions: [HistoryState.Transaction] {
        switch viewMode {
        case .all:
            guard case .loaded(let historyState) = state else { return [] }
            return historyState.transactions
        case .filtered:
            return filteredResult.transactions
        }
    }

    var availableDateRange: ClosedRange<Date> {
        guard case .loaded(let historyState) = state,
              let minDate = historyState.transactions.map(\.date).min(),
              let maxDate = historyState.transactions.map(\.date).max() else {
            return Date.distantPast...Date.distantFuture
        }
        return minDate...maxDate
    }

    func resetFilters() {
        filters = HistoryFilters()
        viewMode = .all
        initializeFiltersIfNeeded()
    }

    func initializeFiltersIfNeeded() {
        guard !filters.didInitialize else { return }
        guard case .loaded(let historyState) = state,
              let minDate = historyState.transactions.map(\.date).min(),
              let maxDate = historyState.transactions.map(\.date).max() else {
            return
        }
        filters.startDate = minDate
        filters.endDate = maxDate
        filters.didInitialize = true
    }

    private static func computeFilteredResult(
        transactions: [HistoryState.Transaction],
        filters: HistoryFilters,
        viewMode: HistoryViewMode
    ) -> FilteredResult {
        guard viewMode == .filtered else {
            return FilteredResult(transactions: transactions, profitLoss: 0)
        }

        var items = transactions
        if filters.closedOnly {
            items = items.filter { $0.action == .positionClosed }
        }
        if filters.dateRangeEnabled {
            let range = Self.normalizedDateRange(startDate: filters.startDate, endDate: filters.endDate)
            items = items.filter { $0.date >= range.start && $0.date < range.end }
        }
        let profitLoss = items.reduce(0.0) { $0 + ($1.profitOrLoss ?? 0) }
        return FilteredResult(transactions: items, profitLoss: profitLoss)
    }

    private static func normalizedDateRange(startDate: Date, endDate: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: min(startDate, endDate))
        let endDay = calendar.startOfDay(for: max(startDate, endDate))
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return (start, end)
    }
}

struct FilteredResult: Equatable {
    var transactions: [HistoryState.Transaction] = []
    var profitLoss: Double = 0

    var profitLossText: String {
        let sign = profitLoss >= 0 ? "+" : ""
        return "\(sign)\(profitLoss.formatted(.currency(code: "PLN")))"
    }
}

struct HistoryFilters: Equatable {
    var closedOnly: Bool = false
    var dateRangeEnabled: Bool = false
    var startDate: Date = Date()
    var endDate: Date = Date()
    var didInitialize: Bool = false
}

enum HistoryViewMode: CaseIterable {
    case all
    case filtered

    var title: String {
        switch self {
        case .all:
            return "All"
        case .filtered:
            return "Filtered"
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

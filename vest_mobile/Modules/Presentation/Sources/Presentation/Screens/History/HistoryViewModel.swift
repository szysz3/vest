import Foundation
import Core
import Domain

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public private(set) var state: ViewState<HistoryState, ViewModelError> = .idle
    @Published public var selectedRange: TimeRange = .all
    @Published public var savingsMode: SavingsMode = .monthly
    @Published public var selectedDate: Date? = nil
    @Published public var selectedSavingId: String? = nil

    private let getPortfolioHistoryUseCase: GetPortfolioHistoryUseCaseProtocol

    public nonisolated init(getPortfolioHistoryUseCase: GetPortfolioHistoryUseCaseProtocol) {
        self.getPortfolioHistoryUseCase = getPortfolioHistoryUseCase
    }

    public func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    public func load() async {
        state = .loading
        do {
            let history = try await getPortfolioHistoryUseCase.execute()
            state = .loaded(HistoryState(history: history))
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }
}

public enum TimeRange: String, CaseIterable, Identifiable, Sendable {
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "ALL"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sixMonths: return "Past 6 Months"
        case .oneYear: return "Past 1 Year"
        case .all: return "All Time"
        }
    }
}

public enum SavingsMode: String, CaseIterable, Identifiable, Sendable {
    case monthly = "Monthly"
    case yearly = "Yearly"

    public var id: String { rawValue }
}

public struct RangeDelta: Equatable, Sendable {
    public let startAmount: Double
    public let endAmount: Double
    public let changeAmount: Double
    public let changePct: Double
    public let actualStartAmount: Double
    public let actualEndAmount: Double
    public let marketProfitAmount: Double
    public let marketProfitPct: Double
    public let rangeLabel: String

    public init(
        startAmount: Double,
        endAmount: Double,
        changeAmount: Double,
        changePct: Double,
        actualStartAmount: Double = 0,
        actualEndAmount: Double = 0,
        marketProfitAmount: Double = 0,
        marketProfitPct: Double = 0,
        rangeLabel: String
    ) {
        self.startAmount = startAmount
        self.endAmount = endAmount
        self.changeAmount = changeAmount
        self.changePct = changePct
        self.actualStartAmount = actualStartAmount
        self.actualEndAmount = actualEndAmount
        self.marketProfitAmount = marketProfitAmount
        self.marketProfitPct = marketProfitPct
        self.rangeLabel = rangeLabel
    }
}

public struct HistoryState: Equatable, Sendable {
    public let history: PortfolioHistory

    public init(history: PortfolioHistory) {
        self.history = history
    }

    public var summary: PortfolioHistorySummary {
        history.summary
    }

    public var snapshots: [PortfolioSnapshotPoint] {
        history.snapshots
    }

    public var monthlySavings: [MonthlySaving] {
        history.monthlySavings
    }

    public var yearlySavings: [YearlySaving] {
        history.yearlySavings
    }

    public var hasMultipleSnapshots: Bool {
        snapshots.count >= 2
    }

    public func filteredSnapshots(for range: TimeRange) -> [PortfolioSnapshotPoint] {
        guard !snapshots.isEmpty else { return [] }
        guard range != .all else { return snapshots }

        let calendar = Calendar.current
        let now = snapshots.last?.date ?? Date()
        let cutoffDate: Date

        switch range {
        case .sixMonths:
            cutoffDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .oneYear:
            cutoffDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .all:
            return snapshots
        }

        let filtered = snapshots.filter { $0.date >= cutoffDate }
        return filtered.isEmpty ? snapshots : filtered
    }

    public func delta(for range: TimeRange) -> RangeDelta {
        let pts = filteredSnapshots(for: range)
        guard let first = pts.first, let last = pts.last else {
            return RangeDelta(
                startAmount: 0,
                endAmount: 0,
                changeAmount: 0,
                changePct: 0,
                actualStartAmount: 0,
                actualEndAmount: 0,
                marketProfitAmount: 0,
                marketProfitPct: 0,
                rangeLabel: range.title
            )
        }

        let start = first.nominalAmount
        let end = last.nominalAmount
        let change = pts.count > 1 ? (round((end - start) * 100.0) / 100.0) : 0.0
        let pct = (start > 0 && pts.count > 1) ? (round((change / start * 100.0) * 100.0) / 100.0) : 0.0
        let actualStart = first.totalAmount
        let actualEnd = last.totalAmount
        let marketProfit = round((actualEnd - end) * 100.0) / 100.0
        let marketProfitPct = end > 0 ? (round((marketProfit / end * 100.0) * 100.0) / 100.0) : 0.0

        return RangeDelta(
            startAmount: start,
            endAmount: end,
            changeAmount: change,
            changePct: pct,
            actualStartAmount: actualStart,
            actualEndAmount: actualEnd,
            marketProfitAmount: marketProfit,
            marketProfitPct: marketProfitPct,
            rangeLabel: range.title
        )
    }

    public var monthlyAverage: Double {
        guard !monthlySavings.isEmpty else { return 0 }
        let activeMonths = (monthlySavings.count > 1 && monthlySavings.first?.amount == 0)
            ? Array(monthlySavings.dropFirst())
            : monthlySavings
        guard !activeMonths.isEmpty else { return 0 }
        let total = activeMonths.reduce(0.0) { $0 + $1.amount }
        return total / Double(activeMonths.count)
    }

    public var yearlyAverage: Double {
        guard !yearlySavings.isEmpty else { return 0 }
        let activeYears = (yearlySavings.count > 1 && yearlySavings.first?.amount == 0)
            ? Array(yearlySavings.dropFirst())
            : yearlySavings
        guard !activeYears.isEmpty else { return 0 }
        let total = activeYears.reduce(0.0) { $0 + $1.amount }
        return total / Double(activeYears.count)
    }
}

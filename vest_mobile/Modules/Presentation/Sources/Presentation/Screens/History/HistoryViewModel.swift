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
    public let rangeLabel: String

    public init(
        startAmount: Double,
        endAmount: Double,
        changeAmount: Double,
        changePct: Double,
        rangeLabel: String
    ) {
        self.startAmount = startAmount
        self.endAmount = endAmount
        self.changeAmount = changeAmount
        self.changePct = changePct
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
            return RangeDelta(startAmount: 0, endAmount: 0, changeAmount: 0, changePct: 0, rangeLabel: range.title)
        }

        let start = first.totalAmount
        let end = last.totalAmount
        let change = round((end - start) * 100.0) / 100.0
        let pct = start > 0 ? (round((change / start * 100.0) * 100.0) / 100.0) : 0.0

        return RangeDelta(
            startAmount: start,
            endAmount: end,
            changeAmount: change,
            changePct: pct,
            rangeLabel: range.title
        )
    }

    public var monthlyAverage: Double {
        guard !monthlySavings.isEmpty else { return 0 }
        let total = monthlySavings.reduce(0.0) { $0 + $1.amount }
        return total / Double(monthlySavings.count)
    }

    public var yearlyAverage: Double {
        guard !yearlySavings.isEmpty else { return 0 }
        let total = yearlySavings.reduce(0.0) { $0 + $1.amount }
        return total / Double(yearlySavings.count)
    }
}

import Foundation
import Testing
import Domain
import Core
@testable import Presentation

private final class StubHistoryUseCase: GetPortfolioHistoryUseCaseProtocol, @unchecked Sendable {
    var historyResult: PortfolioHistory?
    var errorToThrow: Error?

    func execute() async throws -> PortfolioHistory {
        if let error = errorToThrow {
            throw error
        }
        guard let history = historyResult else {
            throw DomainError.unknown("No mock data")
        }
        return history
    }
}

@Suite("HistoryViewModel Tests")
@MainActor
struct HistoryViewModelTests {
    private func makeSampleHistory() -> PortfolioHistory {
        let calendar = Calendar.current
        let now = Date()
        let dates = (0..<12).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: now)
        }

        let snapshots = dates.enumerated().map { index, date in
            let amount = 100000.0 + Double(index) * 5000.0
            let nominal = 95000.0 + Double(index) * 4500.0
            return PortfolioSnapshotPoint(
                id: "snap_\(index)",
                date: date,
                dateString: "2026-\(index + 1)-28",
                totalAmount: amount,
                nominalAmount: nominal,
                amountSaved: 4500.0
            )
        }

        let monthly = (1...12).map { month in
            MonthlySaving(
                id: "2026-\(month)",
                year: 2026,
                month: month,
                label: "M\(month) 2026",
                shortLabel: "M\(month)",
                amount: 4500.0
            )
        }

        let yearly = [
            YearlySaving(id: "2026", year: 2026, label: "2026", amount: 54000.0)
        ]

        let summary = PortfolioHistorySummary(
            currentTotal: 155000.0,
            startingTotal: 100000.0,
            totalSaved: 54000.0,
            totalGrowthPct: 55.0,
            monthlyAverageSaved: 4500.0,
            yearlyAverageSaved: 54000.0,
            currentMonthSaved: 4500.0,
            currentYearSaved: 54000.0
        )

        return PortfolioHistory(
            summary: summary,
            snapshots: snapshots,
            monthlySavings: monthly,
            yearlySavings: yearly
        )
    }

    @Test func initialStateIsIdle() async throws {
        let stub = StubHistoryUseCase()
        let vm = HistoryViewModel(getPortfolioHistoryUseCase: stub)

        #expect(vm.state.isIdle)
        #expect(vm.selectedRange == .all)
        #expect(vm.savingsMode == .monthly)
        #expect(vm.selectedDate == nil)
        #expect(vm.selectedSavingId == nil)
    }

    @Test func loadSuccessSetsLoadedState() async throws {
        let stub = StubHistoryUseCase()
        stub.historyResult = makeSampleHistory()
        let vm = HistoryViewModel(getPortfolioHistoryUseCase: stub)

        await vm.load()

        #expect(vm.state.isLoaded)
        guard let state = vm.state.data else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(state.summary.currentTotal == 155000.0)
        #expect(state.snapshots.count == 12)
        #expect(state.monthlySavings.count == 12)
        #expect(state.yearlySavings.count == 1)
        #expect(state.monthlyAverage == 4500.0)
        #expect(state.yearlyAverage == 54000.0)
    }

    @Test func timeRangeFilteringAndDeltaCalculation() async throws {
        let stub = StubHistoryUseCase()
        stub.historyResult = makeSampleHistory()
        let vm = HistoryViewModel(getPortfolioHistoryUseCase: stub)

        await vm.load()
        guard let state = vm.state.data else {
            Issue.record("Expected loaded state")
            return
        }

        let allPoints = state.filteredSnapshots(for: .all)
        #expect(allPoints.count == 12)

        let sixMonthPoints = state.filteredSnapshots(for: .sixMonths)
        #expect(sixMonthPoints.count <= 7)
        #expect(!sixMonthPoints.isEmpty)

        let deltaAll = state.delta(for: .all)
        #expect(deltaAll.startAmount == 100000.0)
        #expect(deltaAll.endAmount == 155000.0)
        #expect(deltaAll.changeAmount == 55000.0)
        #expect(deltaAll.changePct == 55.0)
    }

    @Test func loadFailureSetsFailedState() async throws {
        let stub = StubHistoryUseCase()
        stub.errorToThrow = DomainError.unknown("Fetch failed")
        let vm = HistoryViewModel(getPortfolioHistoryUseCase: stub)

        await vm.load()

        #expect(vm.state.isFailed)
        #expect(vm.state.error?.errorDescription?.contains("Fetch failed") == true)
    }

    @Test func singleSnapshotStatusQuoBehavior() async throws {
        let singleSnapshot = PortfolioSnapshotPoint(
            id: "snap_0",
            date: Date(),
            dateString: "2026-10-11",
            totalAmount: 125000.0,
            nominalAmount: 115000.0,
            amountSaved: 0.0
        )
        let summary = PortfolioHistorySummary(
            currentTotal: 125000.0,
            startingTotal: 125000.0,
            totalSaved: 0.0,
            totalGrowthPct: 0.0,
            monthlyAverageSaved: 0.0,
            yearlyAverageSaved: 0.0,
            currentMonthSaved: 0.0,
            currentYearSaved: 0.0
        )
        let history = PortfolioHistory(
            summary: summary,
            snapshots: [singleSnapshot],
            monthlySavings: [],
            yearlySavings: []
        )

        let stub = StubHistoryUseCase()
        stub.historyResult = history
        let vm = HistoryViewModel(getPortfolioHistoryUseCase: stub)

        await vm.load()
        guard let state = vm.state.data else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(!state.hasMultipleSnapshots)
        let delta = state.delta(for: .all)
        #expect(delta.startAmount == 125000.0)
        #expect(delta.endAmount == 125000.0)
        #expect(delta.changeAmount == 0.0)
        #expect(delta.changePct == 0.0)
    }
}

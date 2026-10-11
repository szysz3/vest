import Foundation
import Testing
@testable import Domain

private final class MockHistoryTransactionRepository: TransactionRepository, @unchecked Sendable {
    var historyResult: PortfolioHistory?
    var errorToThrow: Error?

    func fetchTransactions() async throws -> [Transaction] { [] }
    func fetchPortfolioDetails() async throws -> [AssetDetail] { [] }
    func fetchStatementSyncStatus() async throws -> StatementSyncStatus {
        StatementSyncStatus(allUploaded: true, uploadedCount: 2, totalCount: 2, lastSyncDate: "2026-08-09", missingSlots: [])
    }

    func fetchPortfolioHistory() async throws -> PortfolioHistory {
        if let error = errorToThrow {
            throw error
        }
        guard let history = historyResult else {
            throw DomainError.unknown("No mock data")
        }
        return history
    }
}

@Suite("Portfolio History Use Case Tests")
struct PortfolioHistoryUseCasesTests {
    @Test func fetchPortfolioHistorySuccess() async throws {
        let repo = MockHistoryTransactionRepository()
        let summary = PortfolioHistorySummary(
            currentTotal: 150000.0,
            startingTotal: 100000.0,
            totalSaved: 50000.0,
            totalGrowthPct: 50.0,
            monthlyAverageSaved: 4166.67,
            yearlyAverageSaved: 50000.0,
            currentMonthSaved: 4000.0,
            currentYearSaved: 32000.0
        )
        let snapshots = [
            PortfolioSnapshotPoint(id: "1", date: Date(), dateString: "2026-01-31", totalAmount: 100000, nominalAmount: 95000, amountSaved: 3000),
            PortfolioSnapshotPoint(id: "2", date: Date(), dateString: "2026-02-28", totalAmount: 150000, nominalAmount: 140000, amountSaved: 4000)
        ]
        let monthly = [
            MonthlySaving(id: "2026-01", year: 2026, month: 1, label: "Jan 2026", shortLabel: "Jan", amount: 3000),
            MonthlySaving(id: "2026-02", year: 2026, month: 2, label: "Feb 2026", shortLabel: "Feb", amount: 4000)
        ]
        let yearly = [
            YearlySaving(id: "2026", year: 2026, label: "2026", amount: 7000)
        ]
        repo.historyResult = PortfolioHistory(
            summary: summary,
            snapshots: snapshots,
            monthlySavings: monthly,
            yearlySavings: yearly
        )

        let useCase = GetPortfolioHistoryUseCase(repository: repo)
        let result = try await useCase.execute()

        #expect(result.summary.currentTotal == 150000.0)
        #expect(result.summary.startingTotal == 100000.0)
        #expect(result.snapshots.count == 2)
        #expect(result.monthlySavings.count == 2)
        #expect(result.yearlySavings.count == 1)
        #expect(result.yearlySavings.first?.amount == 7000)
    }

    @Test func fetchPortfolioHistoryError() async throws {
        let repo = MockHistoryTransactionRepository()
        repo.errorToThrow = DomainError.unknown("Network failed")

        let useCase = GetPortfolioHistoryUseCase(repository: repo)

        await #expect(throws: DomainError.self) {
            _ = try await useCase.execute()
        }
    }
}

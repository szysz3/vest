import Domain
import Foundation

public struct TransactionRepositoryImpl: TransactionRepository {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchTransactions() async throws -> [Transaction] {
        try await httpClient.request(path: "/transactions")
    }

    public func fetchPortfolioDetails() async throws -> [AssetDetail] {
        let responses: [AssetDetailRemoteResponse] = try await httpClient.request(path: "/portfolio/details")
        return responses.compactMap { r in
            guard let assetType = AssetType(rawValue: r.assetType) else { return nil }
            return AssetDetail(
                assetType: assetType,
                details: r.details,
                currency: r.currency ?? "PLN",
                nominalAmount: r.nominalAmount ?? r.totalAmount,
                totalAmount: r.totalAmount,
                profitOrLoss: r.profitOrLoss ?? 0.0,
                profitOrLossPct: r.profitOrLossPct ?? 0.0,
                nominalAmountPLN: r.nominalAmountPLN ?? r.totalAmountPLN,
                totalAmountPLN: r.totalAmountPLN,
                profitOrLossPLN: r.profitOrLossPLN ?? 0.0,
                accountNumber: r.accountNumber,
                weightOz: r.weightOz
            )
        }
    }

    public func fetchStatementSyncStatus() async throws -> StatementSyncStatus {
        let remote: StatementSyncStatusRemoteResponse = try await httpClient.request(path: "/statements/status")
        return StatementSyncStatus(
            allUploaded: remote.allUploaded,
            uploadedCount: remote.uploadedCount,
            totalCount: remote.totalCount,
            lastSyncDate: remote.lastSyncDate,
            missingSlots: remote.missingSlots
        )
    }

    public func fetchPortfolioHistory() async throws -> PortfolioHistory {
        let remote: PortfolioHistoryRemoteResponse = try await httpClient.request(path: "/portfolio/history")
        return remote.toDomain()
    }
}

private struct PortfolioHistoryRemoteResponse: Decodable {
    let summary: PortfolioHistorySummaryRemoteResponse
    let snapshots: [PortfolioSnapshotRemoteResponse]
    let monthlySavings: [MonthlySavingRemoteResponse]
    let yearlySavings: [YearlySavingRemoteResponse]

    func toDomain() -> PortfolioHistory {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let domainSnapshots = snapshots.map { s in
            let parsedDate = dateFormatter.date(from: s.date) ?? Date()
            return PortfolioSnapshotPoint(
                id: s.id,
                date: parsedDate,
                dateString: s.date,
                totalAmount: s.totalAmount,
                nominalAmount: s.nominalAmount,
                amountSaved: s.amountSaved
            )
        }

        let domainMonthly = monthlySavings.map { m in
            MonthlySaving(
                id: m.id,
                year: m.year,
                month: m.month,
                label: m.label,
                shortLabel: m.shortLabel,
                amount: m.amount
            )
        }

        let domainYearly = yearlySavings.map { y in
            YearlySaving(
                id: y.id,
                year: y.year,
                label: y.label,
                amount: y.amount
            )
        }

        return PortfolioHistory(
            summary: summary.toDomain(),
            snapshots: domainSnapshots,
            monthlySavings: domainMonthly,
            yearlySavings: domainYearly
        )
    }
}

private struct PortfolioHistorySummaryRemoteResponse: Decodable {
    let currentTotal: Double
    let startingTotal: Double
    let totalSaved: Double
    let totalGrowthPct: Double
    let monthlyAverageSaved: Double
    let yearlyAverageSaved: Double
    let currentMonthSaved: Double
    let currentYearSaved: Double

    func toDomain() -> PortfolioHistorySummary {
        PortfolioHistorySummary(
            currentTotal: currentTotal,
            startingTotal: startingTotal,
            totalSaved: totalSaved,
            totalGrowthPct: totalGrowthPct,
            monthlyAverageSaved: monthlyAverageSaved,
            yearlyAverageSaved: yearlyAverageSaved,
            currentMonthSaved: currentMonthSaved,
            currentYearSaved: currentYearSaved
        )
    }
}

private struct PortfolioSnapshotRemoteResponse: Decodable {
    let id: String
    let date: String
    let totalAmount: Double
    let nominalAmount: Double
    let amountSaved: Double
}

private struct MonthlySavingRemoteResponse: Decodable {
    let id: String
    let year: Int
    let month: Int
    let label: String
    let shortLabel: String
    let amount: Double
}

private struct YearlySavingRemoteResponse: Decodable {
    let id: String
    let year: Int
    let label: String
    let amount: Double
}

private struct AssetDetailRemoteResponse: Decodable {
    let assetType: String
    let details: String
    let currency: String?
    let nominalAmount: Double?
    let totalAmount: Double
    let profitOrLoss: Double?
    let profitOrLossPct: Double?
    let nominalAmountPLN: Double?
    let totalAmountPLN: Double
    let profitOrLossPLN: Double?
    let accountNumber: String?
    let weightOz: Double?
}

private struct StatementSyncStatusRemoteResponse: Decodable {
    let allUploaded: Bool
    let uploadedCount: Int
    let totalCount: Int
    let lastSyncDate: String?
    let missingSlots: [String]
}

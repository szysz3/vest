import Foundation

public struct PortfolioHistorySummary: Equatable, Sendable, Codable {
    public let currentTotal: Double
    public let startingTotal: Double
    public let totalSaved: Double
    public let totalGrowthPct: Double
    public let monthlyAverageSaved: Double
    public let yearlyAverageSaved: Double
    public let currentMonthSaved: Double
    public let currentYearSaved: Double

    public init(
        currentTotal: Double,
        startingTotal: Double,
        totalSaved: Double,
        totalGrowthPct: Double,
        monthlyAverageSaved: Double,
        yearlyAverageSaved: Double,
        currentMonthSaved: Double,
        currentYearSaved: Double
    ) {
        self.currentTotal = currentTotal
        self.startingTotal = startingTotal
        self.totalSaved = totalSaved
        self.totalGrowthPct = totalGrowthPct
        self.monthlyAverageSaved = monthlyAverageSaved
        self.yearlyAverageSaved = yearlyAverageSaved
        self.currentMonthSaved = currentMonthSaved
        self.currentYearSaved = currentYearSaved
    }
}

public struct PortfolioSnapshotPoint: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let date: Date
    public let dateString: String
    public let totalAmount: Double
    public let nominalAmount: Double
    public let amountSaved: Double

    public init(
        id: String,
        date: Date,
        dateString: String,
        totalAmount: Double,
        nominalAmount: Double,
        amountSaved: Double
    ) {
        self.id = id
        self.date = date
        self.dateString = dateString
        self.totalAmount = totalAmount
        self.nominalAmount = nominalAmount
        self.amountSaved = amountSaved
    }
}

public struct MonthlySaving: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let year: Int
    public let month: Int
    public let label: String
    public let shortLabel: String
    public let amount: Double

    public init(
        id: String,
        year: Int,
        month: Int,
        label: String,
        shortLabel: String,
        amount: Double
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.label = label
        self.shortLabel = shortLabel
        self.amount = amount
    }
}

public struct YearlySaving: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let year: Int
    public let label: String
    public let amount: Double

    public init(
        id: String,
        year: Int,
        label: String,
        amount: Double
    ) {
        self.id = id
        self.year = year
        self.label = label
        self.amount = amount
    }
}

public struct PortfolioHistory: Equatable, Sendable, Codable {
    public let summary: PortfolioHistorySummary
    public let snapshots: [PortfolioSnapshotPoint]
    public let monthlySavings: [MonthlySaving]
    public let yearlySavings: [YearlySaving]

    public init(
        summary: PortfolioHistorySummary,
        snapshots: [PortfolioSnapshotPoint],
        monthlySavings: [MonthlySaving],
        yearlySavings: [YearlySaving]
    ) {
        self.summary = summary
        self.snapshots = snapshots
        self.monthlySavings = monthlySavings
        self.yearlySavings = yearlySavings
    }
}

import Domain
import Foundation

public actor TransactionRepositoryImpl: TransactionRepository {
    private var transactions: [Transaction]
    private let formOptions: TransactionFormOptions

    public init() {
        let calendar = Calendar.current
        self.transactions = [
            Transaction(
                amount: 2500,
                name: "Checking Account",
                action: .cashDeposit,
                assetType: .cash,
                place: "Bank Transfer",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 30)) ?? .now
            ),
            Transaction(
                amount: 2000,
                name: "US Treasury 10Y",
                action: .bought,
                assetType: .bond,
                place: "Broker A",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 28)) ?? .now
            ),
            Transaction(
                amount: 1500,
                name: "Tesla",
                action: .sold,
                assetType: .stock,
                place: "Exchange",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 23)) ?? .now
            ),
            Transaction(
                amount: 400,
                name: "ATM Withdrawal",
                action: .cashWithdrawal,
                assetType: .cash,
                place: "City ATM",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 15)) ?? .now
            ),
            Transaction(
                amount: 800,
                name: "Bitcoin",
                action: .bought,
                assetType: .crypto,
                place: "Exchange",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 10)) ?? .now
            )
        ]

        self.formOptions = TransactionFormOptions(
            assetTypes: [.bond, .stock, .etf, .gold, .cash],
            operators: [
                TransactionOperator(name: "XTB"),
                TransactionOperator(name: "Bank")
            ]
        )
    }

    public func fetchTransactions() async throws -> [Transaction] {
        transactions
    }

    public func addTransaction(_ transaction: Transaction) async throws {
        transactions.insert(transaction, at: 0)
    }

    public func fetchTransactionFormOptions() async throws -> TransactionFormOptions {
        formOptions
    }
}

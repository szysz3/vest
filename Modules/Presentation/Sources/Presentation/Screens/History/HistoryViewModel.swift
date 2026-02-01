import Foundation
import Core

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published private(set) var state: ViewState<HistoryState, ViewModelError> = .idle

    public nonisolated init() {}

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func load() async {
        state = .loading
        state = .loaded(HistoryState.demo())
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

        public init(
            id: UUID = UUID(),
            amount: Double,
            name: String,
            action: Action,
            assetType: AssetType,
            place: String,
            date: Date
        ) {
            self.id = id
            self.amount = amount
            self.name = name
            self.action = action
            self.assetType = assetType
            self.place = place
            self.date = date
        }
    }

    enum Action: String, CaseIterable, Sendable {
        case bought
        case sold

        var title: String {
            switch self {
            case .bought:
                return "Bought"
            case .sold:
                return "Sold"
            }
        }

        var accentColor: TransactionTone { .mint }
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

        var tone: TransactionTone {
            switch self {
            case .bond:
                return .sand
            case .etf:
                return .ocean
            case .stock:
                return .electric
            case .crypto:
                return .violet
            case .gold:
                return .sunset
            case .cash:
                return .mint
            }
        }
    }

    enum TransactionTone: Sendable {
        case electric
        case mint
        case sunset
        case violet
        case ocean
        case sand
    }
}

public extension HistoryState {
    static func demo() -> HistoryState {
        let calendar = Calendar.current
        let transactions: [Transaction] = [
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
                amount: 800,
                name: "Bitcoin",
                action: .bought,
                assetType: .crypto,
                place: "Exchange",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 10)) ?? .now
            )
        ]

        return HistoryState(transactions: transactions)
    }
}

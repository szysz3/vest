import Foundation
import Core
import Domain

@MainActor
public final class PortfolioViewModel: ObservableObject {
    @Published private(set) var state: ViewState<PortfolioState, ViewModelError> = .idle
    @Published private(set) var syncStatus: StatementSyncStatus?

    private let getPortfolioSummaryUseCase: GetPortfolioSummaryUseCaseProtocol
    private let getStatementSyncStatusUseCase: GetStatementSyncStatusUseCaseProtocol

    public nonisolated init(
        getPortfolioSummaryUseCase: GetPortfolioSummaryUseCaseProtocol,
        getStatementSyncStatusUseCase: GetStatementSyncStatusUseCaseProtocol
    ) {
        self.getPortfolioSummaryUseCase = getPortfolioSummaryUseCase
        self.getStatementSyncStatusUseCase = getStatementSyncStatusUseCase
    }

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            async let summaryTask = getPortfolioSummaryUseCase.execute()
            async let syncStatusTask = getStatementSyncStatusUseCase.execute()

            let (summary, syncStatus) = try await (summaryTask, syncStatusTask)
            self.syncStatus = syncStatus

            let assets = summary.assets.map { PortfolioState.Asset(domainAsset: $0) }
            state = .loaded(
                PortfolioState(
                    nominalAmount: summary.nominalAmount,
                    totalAmount: summary.totalAmount,
                    profitOrLoss: summary.profitOrLoss,
                    profitOrLossPct: summary.profitOrLossPct,
                    assets: assets
                )
            )
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }
}

public struct PortfolioState: Equatable, Sendable {
    public let nominalAmount: Double
    public let totalAmount: Double
    public let profitOrLoss: Double
    public let profitOrLossPct: Double
    public let assets: [Asset]

    public init(
        nominalAmount: Double,
        totalAmount: Double,
        profitOrLoss: Double,
        profitOrLossPct: Double,
        assets: [Asset]
    ) {
        self.nominalAmount = nominalAmount
        self.totalAmount = totalAmount
        self.profitOrLoss = profitOrLoss
        self.profitOrLossPct = profitOrLossPct
        self.assets = assets
    }
}

public extension PortfolioState {
    struct Asset: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let amount: Double
        public let icon: String
        public let color: VestTone

        public init(
            id: UUID = UUID(),
            name: String,
            amount: Double,
            icon: String,
            color: VestTone
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.icon = icon
            self.color = color
        }

        public init(domainAsset: Domain.PortfolioAsset) {
            let display = AssetDisplay.from(assetType: domainAsset.assetType)
            self.init(
                id: UUID(),
                name: display.name,
                amount: domainAsset.amount,
                icon: display.icon,
                color: display.color
            )
        }
    }
}

private enum AssetDisplay {
    case bond
    case etf
    case stock
    case crypto
    case gold
    case cash

    var name: String {
        switch self {
        case .bond: return "Bond"
        case .etf: return "ETF"
        case .stock: return "Stock"
        case .crypto: return "Crypto"
        case .gold: return "Gold"
        case .cash: return "Cash"
        }
    }

    var icon: String {
        switch self {
        case .bond: return "doc.text.fill"
        case .etf: return "chart.line.uptrend.xyaxis"
        case .stock: return "building.columns.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .gold: return "circle.hexagongrid.fill"
        case .cash: return "banknote.fill"
        }
    }

    var color: VestTone {
        switch self {
        case .bond: return .rose
        case .etf: return .ocean
        case .stock: return .electric
        case .crypto: return .violet
        case .gold: return .amber
        case .cash: return .sage
        }
    }

    static func from(assetType: AssetType) -> AssetDisplay {
        switch assetType {
        case .bond: return .bond
        case .etf: return .etf
        case .stock: return .stock
        case .crypto: return .crypto
        case .gold: return .gold
        case .cash: return .cash
        }
    }
}

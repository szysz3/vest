import Foundation
import Core

@MainActor
public final class PortfolioViewModel: ObservableObject {
    @Published private(set) var state: ViewState<PortfolioState, ViewModelError> = .idle

    public nonisolated init() {}

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func load() async {
        state = .loading
        state = .loaded(.mock)
    }
}

public struct PortfolioState: Equatable, Sendable {
    public let totalAmount: Double
    public let assets: [Asset]

    public init(totalAmount: Double, assets: [Asset]) {
        self.totalAmount = totalAmount
        self.assets = assets
    }
}

public extension PortfolioState {
    struct Asset: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let amount: Double
        public let icon: String
        public let color: AssetColor

        public init(
            id: UUID = UUID(),
            name: String,
            amount: Double,
            icon: String,
            color: AssetColor
        ) {
            self.id = id
            self.name = name
            self.amount = amount
            self.icon = icon
            self.color = color
        }
    }

    enum AssetColor: String, Sendable {
        case electric
        case mint
        case sunset
        case violet
        case ocean
        case sand
    }

    static let mock: PortfolioState = {
        let assets: [Asset] = [
            Asset(name: "Global Equities", amount: 148_450, icon: "globe.americas.fill", color: .electric),
            Asset(name: "Private Credit", amount: 62_300, icon: "building.2.fill", color: .mint),
            Asset(name: "Digital Assets", amount: 41_900, icon: "bitcoinsign.circle.fill", color: .sunset),
            Asset(name: "Real Estate", amount: 36_850, icon: "house.fill", color: .violet),
            Asset(name: "Treasury Cash", amount: 18_500, icon: "banknote.fill", color: .ocean),
            Asset(name: "Alternatives", amount: 12_000, icon: "sparkles", color: .sand)
        ]
        let total = assets.reduce(0) { $0 + $1.amount }
        return PortfolioState(totalAmount: total, assets: assets)
    }()
}

import SwiftUI
import Factory

public struct NavigationTabContainer: View {
    @State private var selectedTab: Tab = .portfolio
    private let portfolioViewModel: PortfolioViewModel
    private let historyViewModel: HistoryViewModel
    private let detailsViewModel: DetailsViewModel

    public init() {
        let portfolio = Container.shared.portfolioViewModel()
        let history = Container.shared.historyViewModel()
        let details = Container.shared.detailsViewModel()
        portfolio.onTransactionAdded = { [weak history, weak details] in
            await history?.load()
            await details?.load()
        }
        details.onTransactionAdded = { [weak portfolio, weak history] in
            await portfolio?.load()
            await history?.load()
        }
        self.portfolioViewModel = portfolio
        self.historyViewModel = history
        self.detailsViewModel = details
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PortfolioScreen(viewModel: portfolioViewModel)
                    .navigationTitle(Tab.portfolio.title)
                    .preferredColorScheme(.dark)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label(Tab.portfolio.title, systemImage: Tab.portfolio.icon) }
            .tag(Tab.portfolio)

            NavigationStack {
                DetailsScreen(viewModel: detailsViewModel)
                    .navigationTitle(Tab.details.title)
                    .preferredColorScheme(.dark)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label(Tab.details.title, systemImage: Tab.details.icon) }
            .tag(Tab.details)

            NavigationStack {
                HistoryScreen(viewModel: historyViewModel)
                    .navigationTitle(Tab.history.title)
                    .preferredColorScheme(.dark)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label(Tab.history.title, systemImage: Tab.history.icon) }
            .tag(Tab.history)
        }
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

extension NavigationTabContainer {
    enum Tab: Int {
        case portfolio
        case details
        case history

        var title: String {
            switch self {
            case .portfolio: "Portfolio"
            case .details: "Details"
            case .history: "History"
            }
        }

        var icon: String {
            switch self {
            case .portfolio: "chart.pie.fill"
            case .details: "square.stack.3d.up"
            case .history: "clock.fill"
            }
        }
    }
}

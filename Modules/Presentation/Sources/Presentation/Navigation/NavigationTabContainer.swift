import SwiftUI
import Factory

public struct NavigationTabContainer: View {
    @State private var selectedTab: Tab = .portfolio
    private let portfolioViewModel: PortfolioViewModel
    private let historyViewModel: HistoryViewModel

    public init() {
        self.portfolioViewModel = Container.shared.portfolioViewModel()
        self.historyViewModel = Container.shared.historyViewModel()
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PortfolioScreen(viewModel: portfolioViewModel)
                    .navigationTitle(Tab.portfolio.title)
            }
            .tabItem { Label(Tab.portfolio.title, systemImage: Tab.portfolio.icon) }
            .tag(Tab.portfolio)

            NavigationStack {
                HistoryScreen(viewModel: historyViewModel)
                    .navigationTitle(Tab.history.title)
            }
            .tabItem { Label(Tab.history.title, systemImage: Tab.history.icon) }
            .tag(Tab.history)
        }
    }
}

extension NavigationTabContainer {
    enum Tab: Int {
        case portfolio
        case history

        var title: String {
            switch self {
            case .portfolio: "Portfolio"
            case .history: "History"
            }
        }

        var icon: String {
            switch self {
            case .portfolio: "chart.pie.fill"
            case .history: "clock.fill"
            }
        }
    }
}

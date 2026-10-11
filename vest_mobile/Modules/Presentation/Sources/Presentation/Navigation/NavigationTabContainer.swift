import SwiftUI
import Factory

public struct NavigationTabContainer: View {
    @State private var selectedTab: Tab = .portfolio
    private let portfolioViewModel: PortfolioViewModel
    private let detailsViewModel: DetailsViewModel
    private let historyViewModel: HistoryViewModel

    public init() {
        self.portfolioViewModel = Container.shared.portfolioViewModel()
        self.detailsViewModel = Container.shared.detailsViewModel()
        self.historyViewModel = Container.shared.historyViewModel()
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PortfolioScreen(viewModel: portfolioViewModel)
                    .navigationTitle(Tab.portfolio.title)
                    .preferredColorScheme(.dark)
                    #if os(iOS)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    #endif
            }
            .tabItem { Label(Tab.portfolio.title, systemImage: Tab.portfolio.icon) }
            .tag(Tab.portfolio)

            NavigationStack {
                DetailsScreen(viewModel: detailsViewModel)
                    .navigationTitle(Tab.details.title)
                    .preferredColorScheme(.dark)
                    #if os(iOS)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    #endif
            }
            .tabItem { Label(Tab.details.title, systemImage: Tab.details.icon) }
            .tag(Tab.details)

            NavigationStack {
                HistoryScreen(viewModel: historyViewModel)
                    .navigationTitle(Tab.history.title)
                    .preferredColorScheme(.dark)
                    #if os(iOS)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    #endif
            }
            .tabItem { Label(Tab.history.title, systemImage: Tab.history.icon) }
            .tag(Tab.history)
        }
        #if os(iOS)
        .toolbarColorScheme(.dark, for: .tabBar)
        #endif
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
            case .history: "chart.line.uptrend.xyaxis"
            }
        }
    }
}

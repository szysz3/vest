import Core
import Domain
import Factory

public extension Container {
    var portfolioViewModel: Factory<PortfolioViewModel> {
        self { PortfolioViewModel() }
    }

    var historyViewModel: Factory<HistoryViewModel> {
        self { HistoryViewModel() }
    }
}

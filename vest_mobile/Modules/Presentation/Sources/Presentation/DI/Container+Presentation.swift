import Core
import Domain
import Factory

public extension Container {
    var portfolioViewModel: Factory<PortfolioViewModel> {
        self {
            PortfolioViewModel(
                getPortfolioSummaryUseCase: self.getPortfolioSummaryUseCase(),
                addTransactionUseCase: self.addTransactionUseCase(),
                getTransactionFormOptionsUseCase: self.getTransactionFormOptionsUseCase()
            )
        }
    }

    var historyViewModel: Factory<HistoryViewModel> {
        self { HistoryViewModel(getTransactionsUseCase: self.getTransactionsUseCase()) }
    }
}

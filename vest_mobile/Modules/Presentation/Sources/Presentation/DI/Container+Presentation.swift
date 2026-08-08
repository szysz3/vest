import Core
import Domain
import Factory

public extension Container {
    var portfolioViewModel: Factory<PortfolioViewModel> {
        self {
            PortfolioViewModel(
                getPortfolioSummaryUseCase: self.getPortfolioSummaryUseCase(),
                getStatementSyncStatusUseCase: self.getStatementSyncStatusUseCase()
            )
        }
    }

    var detailsViewModel: Factory<DetailsViewModel> {
        self {
            DetailsViewModel(
                getPortfolioDetailsUseCase: self.getPortfolioDetailsUseCase()
            )
        }
    }

    var lockViewModel: Factory<LockViewModel> {
        self { LockViewModel(authenticateWithBiometricsUseCase: self.authenticateWithBiometricsUseCase()) }
    }
}

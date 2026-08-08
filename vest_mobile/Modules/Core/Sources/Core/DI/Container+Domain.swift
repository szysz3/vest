import Domain
import Factory

public extension Container {
    var getTransactionsUseCase: Factory<GetTransactionsUseCaseProtocol> {
        self {
            GetTransactionsUseCase(repository: self.transactionRepository())
        }
    }

    var getPortfolioSummaryUseCase: Factory<GetPortfolioSummaryUseCaseProtocol> {
        self {
            GetPortfolioSummaryUseCase(repository: self.transactionRepository())
        }
    }

    var getPortfolioDetailsUseCase: Factory<GetPortfolioDetailsUseCaseProtocol> {
        self {
            GetPortfolioDetailsUseCase(repository: self.transactionRepository())
        }
    }

    var getStatementSyncStatusUseCase: Factory<GetStatementSyncStatusUseCaseProtocol> {
        self {
            GetStatementSyncStatusUseCase(repository: self.transactionRepository())
        }
    }

    var authenticateWithBiometricsUseCase: Factory<AuthenticateWithBiometricsUseCaseProtocol> {
        self {
            AuthenticateWithBiometricsUseCase(repository: self.biometricRepository())
        }
    }
}

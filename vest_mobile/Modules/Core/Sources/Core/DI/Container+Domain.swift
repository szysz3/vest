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

    var getFixedAssetsUseCase: Factory<GetFixedAssetsUseCaseProtocol> {
        self {
            GetFixedAssetsUseCase(repository: self.fixedAssetRepository())
        }
    }

    var createFixedAssetUseCase: Factory<CreateFixedAssetUseCaseProtocol> {
        self {
            CreateFixedAssetUseCase(repository: self.fixedAssetRepository())
        }
    }

    var updateFixedAssetUseCase: Factory<UpdateFixedAssetUseCaseProtocol> {
        self {
            UpdateFixedAssetUseCase(repository: self.fixedAssetRepository())
        }
    }

    var deleteFixedAssetUseCase: Factory<DeleteFixedAssetUseCaseProtocol> {
        self {
            DeleteFixedAssetUseCase(repository: self.fixedAssetRepository())
        }
    }
}


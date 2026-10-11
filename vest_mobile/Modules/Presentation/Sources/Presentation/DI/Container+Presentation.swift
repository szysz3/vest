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

    @MainActor
    func makeFixedAssetViewModel(
        mode: FixedAssetViewModel.Mode = .add,
        assetType: AssetType = .cash,
        details: String = "",
        amount: Double? = nil,
        currency: String = "PLN",
        weightOz: Double? = nil
    ) -> FixedAssetViewModel {

        FixedAssetViewModel(
            mode: mode,
            initialAssetType: assetType,
            initialDetails: details,
            initialAmount: amount,
            initialCurrency: currency,
            initialWeightOz: weightOz,
            createFixedAssetUseCase: self.createFixedAssetUseCase(),
            updateFixedAssetUseCase: self.updateFixedAssetUseCase(),
            deleteFixedAssetUseCase: self.deleteFixedAssetUseCase()
        )
    }
}


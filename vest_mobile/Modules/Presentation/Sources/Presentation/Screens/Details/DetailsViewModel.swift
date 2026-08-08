import Foundation
import Core
import Domain

@MainActor
public final class DetailsViewModel: ObservableObject {
    @Published private(set) var state: ViewState<DetailsState, ViewModelError> = .idle

    private let getPortfolioDetailsUseCase: GetPortfolioDetailsUseCaseProtocol

    public nonisolated init(
        getPortfolioDetailsUseCase: GetPortfolioDetailsUseCaseProtocol
    ) {
        self.getPortfolioDetailsUseCase = getPortfolioDetailsUseCase
    }

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            let details = try await getPortfolioDetailsUseCase.execute()
            let grouped = Dictionary(grouping: details, by: { $0.assetType })
            let sections = grouped
                .map { assetType, assets in
                    DetailsState.Section(
                        assetType: assetType,
                        items: assets.map { detail in
                            DetailsState.Item(
                                id: detail.id,
                                details: detail.details,
                                assetType: detail.assetType,
                                currency: detail.currency,
                                nominalAmount: detail.nominalAmount,
                                totalAmount: detail.totalAmount,
                                profitOrLoss: detail.profitOrLoss,
                                profitOrLossPct: detail.profitOrLossPct,
                                nominalAmountPLN: detail.nominalAmountPLN,
                                totalAmountPLN: detail.totalAmountPLN,
                                profitOrLossPLN: detail.profitOrLossPLN
                            )
                        }.sorted { $0.details < $1.details }
                    )
                }
                .sorted { $0.assetType.rawValue < $1.assetType.rawValue }
            state = .loaded(DetailsState(sections: sections))
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }
}

public struct DetailsState: Equatable, Sendable {
    public let sections: [Section]

    public struct Section: Equatable, Sendable, Identifiable {
        public var id: String { assetType.rawValue }
        public let assetType: AssetType
        public let items: [Item]
    }

    public struct Item: Equatable, Sendable, Identifiable {
        public let id: String
        public let details: String
        public let assetType: AssetType
        public let currency: String
        public let nominalAmount: Double
        public let totalAmount: Double
        public let profitOrLoss: Double
        public let profitOrLossPct: Double
        public let nominalAmountPLN: Double
        public let totalAmountPLN: Double
        public let profitOrLossPLN: Double
    }
}

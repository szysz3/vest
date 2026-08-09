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
                                profitOrLossPLN: detail.profitOrLossPLN,
                                accountNumber: detail.accountNumber
                            )
                        }.sorted { item1, item2 in
                            if assetType == .bond {
                                let k1 = parseBondMaturityKey(item1.details)
                                let k2 = parseBondMaturityKey(item2.details)
                                if k1.0 != k2.0 { return k1.0 < k2.0 }
                                if k1.1 != k2.1 { return k1.1 < k2.1 }
                                return item1.details < item2.details
                            } else {
                                return item1.details < item2.details
                            }
                        }
                    )
                }
                .sorted { $0.assetType.rawValue < $1.assetType.rawValue }
            state = .loaded(DetailsState(sections: sections))
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }
}

private func parseBondMaturityKey(_ text: String) -> (Int, Int, String) {
    let upper = text.uppercased()
    let pattern = #"([A-Z]{2,4})\s*(\d{2})(\d{2})"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: upper, options: [], range: NSRange(location: 0, length: upper.utf16.count)) {
        if let mmRange = Range(match.range(at: 2), in: upper),
           let yyRange = Range(match.range(at: 3), in: upper),
           let mm = Int(upper[mmRange]),
           let yy = Int(upper[yyRange]),
           (1...12).contains(mm) {
            let year = 2000 + yy
            return (year, mm, text)
        }
    }
    let fallbackPattern = #"\b(\d{2})(\d{2})\b"#
    if let regex = try? NSRegularExpression(pattern: fallbackPattern),
       let match = regex.firstMatch(in: upper, options: [], range: NSRange(location: 0, length: upper.utf16.count)) {
        if let mmRange = Range(match.range(at: 1), in: upper),
           let yyRange = Range(match.range(at: 2), in: upper),
           let mm = Int(upper[mmRange]),
           let yy = Int(upper[yyRange]),
           (1...12).contains(mm) {
            let year = 2000 + yy
            return (year, mm, text)
        }
    }
    return (9999, 99, text)
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
        public let accountNumber: String?
    }
}

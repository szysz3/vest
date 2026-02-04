import Foundation
import Core
import Domain

@MainActor
public final class DetailsViewModel: ObservableObject {
    @Published private(set) var state: ViewState<DetailsState, ViewModelError> = .idle
    @Published var sellSheet: SellSheetState?

    private let getPortfolioDetailsUseCase: GetPortfolioDetailsUseCaseProtocol
    private let addTransactionUseCase: AddTransactionUseCaseProtocol
    private let getTransactionFormOptionsUseCase: GetTransactionFormOptionsUseCaseProtocol
    private var formOptions: TransactionFormOptions = .empty
    var onTransactionAdded: (@Sendable () async -> Void)?

    public nonisolated init(
        getPortfolioDetailsUseCase: GetPortfolioDetailsUseCaseProtocol,
        addTransactionUseCase: AddTransactionUseCaseProtocol,
        getTransactionFormOptionsUseCase: GetTransactionFormOptionsUseCaseProtocol
    ) {
        self.getPortfolioDetailsUseCase = getPortfolioDetailsUseCase
        self.addTransactionUseCase = addTransactionUseCase
        self.getTransactionFormOptionsUseCase = getTransactionFormOptionsUseCase
    }

    func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            if formOptions.isEmpty {
                formOptions = try await getTransactionFormOptionsUseCase.execute()
            }
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
                                totalAmount: detail.totalAmount
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

    private func reloadDetails() async {
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
                                totalAmount: detail.totalAmount
                            )
                        }.sorted { $0.details < $1.details }
                    )
                }
                .sorted { $0.assetType.rawValue < $1.assetType.rawValue }
            state = .loaded(DetailsState(sections: sections))
        } catch {
            // Keep current state on error rather than showing failure
        }
    }

    func requestSell(item: DetailsState.Item) {
        sellSheet = SellSheetState(
            details: item.details,
            assetType: item.assetType,
            holdingAmount: item.totalAmount,
            sellAmountText: String(format: "%.2f", item.totalAmount),
            closePosition: false,
            selectedOperator: formOptions.operators.first ?? TransactionOperator(name: "XTB"),
            availableOperators: formOptions.operators
        )
    }

    func confirmSell() async {
        guard var sheet = sellSheet else { return }
        let normalized = sheet.sellAmountText.replacingOccurrences(of: ",", with: ".")
        guard let sellAmount = Double(normalized), sellAmount > 0 else { return }

        sheet.isSaving = true
        sellSheet = sheet

        let action: TransactionAction = sheet.closePosition ? .positionClosed : .sold
        let profitOrLoss: Double? = sheet.closePosition ? (sellAmount - sheet.holdingAmount) : nil
        let transactionAmount = sheet.closePosition ? sheet.holdingAmount : sellAmount
        let name = sheet.details

        let transaction = Transaction(
            amount: transactionAmount,
            name: name,
            action: action,
            assetType: sheet.assetType,
            place: sheet.selectedOperator.name,
            date: .now,
            details: sheet.details,
            profitOrLoss: profitOrLoss
        )

        let cashTransaction = Transaction(
            amount: sellAmount,
            name: "Cash",
            action: .cashDeposit,
            assetType: .cash,
            place: sheet.selectedOperator.name,
            date: .now
        )

        do {
            try await addTransactionUseCase.execute(transactions: [transaction, cashTransaction])
            sheet.isSaving = false
            sheet.isConfirmed = true
            sellSheet = sheet
            try? await Task.sleep(for: .milliseconds(800))
            sellSheet = nil
            await reloadDetails()
            await onTransactionAdded?()
        } catch {
            sheet.isSaving = false
            sellSheet = sheet
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
        public let totalAmount: Double
    }
}

struct SellSheetState: Equatable {
    let details: String
    let assetType: AssetType
    let holdingAmount: Double
    var sellAmountText: String
    var closePosition: Bool
    var selectedOperator: TransactionOperator
    let availableOperators: [TransactionOperator]
    var isSaving: Bool = false
    var isConfirmed: Bool = false

    var parsedSellAmount: Double? {
        let normalized = sellAmountText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    var profitOrLoss: Double? {
        guard closePosition, let sell = parsedSellAmount else { return nil }
        return sell - holdingAmount
    }

    var isValid: Bool {
        guard let amount = parsedSellAmount, amount > 0 else { return false }
        if !closePosition && amount > holdingAmount { return false }
        return true
    }
}

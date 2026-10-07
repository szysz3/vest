import Foundation
import Core
import Domain

@MainActor
public final class FixedAssetViewModel: ObservableObject {
    public enum Mode: Equatable {
        case add
        case edit(id: String)

        public var title: String {
            switch self {
            case .add: return "Add Fixed Asset"
            case .edit: return "Edit Fixed Asset"
            }
        }

        public var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    public let mode: Mode

    @Published public var assetType: AssetType = .cash
    @Published public var details: String = ""
    @Published public var amountText: String = ""
    @Published public var currency: String = "PLN"
    @Published public var isSaving: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var showDeleteConfirmation: Bool = false

    private let createFixedAssetUseCase: CreateFixedAssetUseCaseProtocol
    private let updateFixedAssetUseCase: UpdateFixedAssetUseCaseProtocol
    private let deleteFixedAssetUseCase: DeleteFixedAssetUseCaseProtocol

    public init(
        mode: Mode = .add,
        initialAssetType: AssetType = .cash,
        initialDetails: String = "",
        initialAmount: Double? = nil,
        initialCurrency: String = "PLN",
        createFixedAssetUseCase: CreateFixedAssetUseCaseProtocol,
        updateFixedAssetUseCase: UpdateFixedAssetUseCaseProtocol,
        deleteFixedAssetUseCase: DeleteFixedAssetUseCaseProtocol
    ) {
        self.mode = mode
        self.assetType = initialAssetType
        self.details = initialDetails
        if let initialAmount {
            self.amountText = initialAmount > 0 ? String(format: "%.2f", initialAmount).replacingOccurrences(of: ".00", with: "") : ""
        } else {
            self.amountText = ""
        }
        self.currency = initialCurrency
        self.createFixedAssetUseCase = createFixedAssetUseCase
        self.updateFixedAssetUseCase = updateFixedAssetUseCase
        self.deleteFixedAssetUseCase = deleteFixedAssetUseCase
    }


    public var parsedAmount: Double? {
        let normalized = amountText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else { return nil }
        return value
    }

    public var isFormValid: Bool {
        guard !details.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let amount = parsedAmount, amount >= 0 else { return false }
        return true
    }

    public func save() async -> Bool {
        guard isFormValid, let amount = parsedAmount else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let draft = FixedAssetDraft(
            assetType: assetType,
            details: details.trimmingCharacters(in: .whitespaces),
            amount: amount,
            currency: currency
        )

        do {
            switch mode {
            case .add:
                _ = try await createFixedAssetUseCase.execute(draft)
            case .edit(let id):
                _ = try await updateFixedAssetUseCase.execute(id: id, draft: draft)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func delete() async -> Bool {
        guard case .edit(let id) = mode else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await deleteFixedAssetUseCase.execute(id: id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

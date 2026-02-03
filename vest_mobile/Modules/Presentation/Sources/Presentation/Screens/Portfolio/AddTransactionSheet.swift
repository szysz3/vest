import SwiftUI
import Domain

struct AddTransactionDraft: Sendable {
    let amount: Double
    let action: TransactionAction
    let assetType: AssetType
    let operatorName: String
    let details: String
}

struct AddTransactionSheet: View {
    let options: TransactionFormOptions
    let onSave: @Sendable (AddTransactionDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    @FocusState private var detailsFocused: Bool

    @State private var amountText = ""
    @State private var detailsText = ""
    @State private var selectedAssetType: AssetType
    @State private var selectedAction: TransactionActionOption
    @State private var selectedOperator: TransactionOperator
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        options: TransactionFormOptions,
        onSave: @escaping @Sendable (AddTransactionDraft) async throws -> Void
    ) {
        self.options = options
        self.onSave = onSave
        let defaultAssetType = options.assetTypes.first ?? .cash
        let defaultOperator = options.operators.first ?? TransactionOperator(name: "XTB")
        _selectedAssetType = State(initialValue: defaultAssetType)
        _selectedOperator = State(initialValue: defaultOperator)
        _selectedAction = State(initialValue: defaultAssetType == .cash ? .cashDeposit : .buy)
    }

    private var isCash: Bool {
        selectedAssetType == .cash
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if options.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    header
                    amountSection
                    if isCash {
                        actionSection
                    }
                    assetSection
                    if !isCash {
                        detailsSection
                    }
                    operatorSection
                    saveButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 6)
        }
        .scrollDismissesKeyboard(.immediately)
        .onTapGesture {
            amountFocused = false
            detailsFocused = false
        }
        .background(sheetBackground)
        .environment(\.colorScheme, .dark)
        .presentationDetents([.fraction(0.9)])
        .presentationDragIndicator(.visible)
        .alert("Unable to Add Transaction", isPresented: hasErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .onChange(of: options.assetTypes) { newValue in
            guard let first = newValue.first else { return }
            if !newValue.contains(selectedAssetType) {
                selectedAssetType = first
            }
        }
        .onChange(of: options.operators) { newValue in
            guard let first = newValue.first else { return }
            if !newValue.contains(where: { $0.id == selectedOperator.id }) {
                selectedOperator = first
            }
        }
        .onChange(of: selectedAssetType) { newValue in
            if newValue == .cash {
                let actions = availableActions(for: newValue)
                if !actions.contains(selectedAction) {
                    selectedAction = actions.first ?? .cashDeposit
                }
            } else {
                selectedAction = .buy
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add Transaction")
                        .font(.title3.weight(.semibold))
                    Text(isCash ? "Record a cash deposit or withdrawal." : "Record a new purchase.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            Divider()
                .overlay(Color.white.opacity(0.08))
        }
    }

    private var amountSection: some View {
        SectionCard(title: "Amount") {
            HStack(spacing: 12) {
                Text("PLN")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var actionSection: some View {
        SectionCard(title: "Transaction Type") {
            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(availableActions(for: selectedAssetType), id: \.self) { action in
                    SelectableTile(
                        title: action.title,
                        isSelected: action == selectedAction,
                        color: action.accentColor,
                        iconName: action.iconName
                    ) {
                        selectedAction = action
                    }
                }
            }
        }
    }

    private var assetSection: some View {
        SectionCard(title: "Asset Type") {
            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(options.assetTypes, id: \.self) { assetType in
                    SelectableTile(
                        title: assetType.formTitle,
                        isSelected: assetType == selectedAssetType,
                        color: assetType.toneColor,
                        iconName: assetType.iconName
                    ) {
                        selectedAssetType = assetType
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        SectionCard(title: "Symbol") {
            TextField("e.g. VWCE.DE, ROR0127", text: $detailsText)
                .textInputAutocapitalization(.characters)
                .focused($detailsFocused)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
    }

    private var operatorSection: some View {
        SectionCard(title: "Operator") {
            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(options.operators) { item in
                    SelectableTile(
                        title: item.name,
                        isSelected: item.id == selectedOperator.id,
                        color: VestTone.electric.color,
                        iconName: "building.2.fill"
                    ) {
                        selectedOperator = item
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await saveTransaction() }
        } label: {
            HStack {
                Spacer()
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Add Transaction")
                        .font(.headline)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isFormValid ? VestActionColor.positive : Color.white.opacity(0.12))
            )
        }
        .disabled(!isFormValid || isSaving)
        .foregroundStyle(isFormValid ? .black : .secondary)
        .padding(.top, 4)
    }

    private var sheetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.10, blue: 0.16),
                Color(red: 0.11, green: 0.13, blue: 0.20),
                Color(red: 0.16, green: 0.18, blue: 0.26)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var hasErrorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )
    }

    private var parsedAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return nil }
        return value
    }

    private var tileColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var isFormValid: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        if !isCash && detailsText.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        if isCash {
            return availableActions(for: selectedAssetType).contains(selectedAction)
        }
        return true
    }

    private func availableActions(for assetType: AssetType) -> [TransactionActionOption] {
        if assetType == .cash {
            return [.cashDeposit, .cashWithdrawal]
        }
        return [.buy]
    }

    private func saveTransaction() async {
        guard let amount = parsedAmount else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let action: TransactionAction = isCash ? selectedAction.action : .bought
            try await onSave(
                AddTransactionDraft(
                    amount: amount,
                    action: action,
                    assetType: selectedAssetType,
                    operatorName: selectedOperator.name,
                    details: isCash ? "" : detailsText.trimmingCharacters(in: .whitespaces)
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum TransactionActionOption: String, CaseIterable, Hashable {
    case buy
    case cashDeposit
    case cashWithdrawal

    var title: String {
        switch self {
        case .buy:
            return "Buy"
        case .cashDeposit:
            return "Cash Deposit"
        case .cashWithdrawal:
            return "Cash Withdrawal"
        }
    }

    var action: TransactionAction {
        switch self {
        case .buy:
            return .bought
        case .cashDeposit:
            return .cashDeposit
        case .cashWithdrawal:
            return .cashWithdrawal
        }
    }

    var accentColor: Color {
        switch self {
        case .buy, .cashDeposit:
            return VestActionColor.positive
        case .cashWithdrawal:
            return VestActionColor.negative
        }
    }

    var iconName: String {
        switch self {
        case .buy:
            return "arrow.up.right"
        case .cashDeposit:
            return "arrow.down.circle.fill"
        case .cashWithdrawal:
            return "arrow.up.circle.fill"
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content
        }
        .padding(14)
        .background(VestCardBackground(cornerRadius: 16))
    }
}

private struct SelectableTile: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.35))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.35))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? color : Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

private extension AssetType {
    var formTitle: String {
        switch self {
        case .bond:
            return "Treasury Bond"
        case .stock:
            return "Shares"
        case .etf:
            return "ETF"
        case .gold:
            return "Gold"
        case .cash:
            return "Cash"
        case .crypto:
            return "Crypto"
        }
    }

    var toneColor: Color {
        vestTone.color
    }

    private var vestTone: VestTone {
        switch self {
        case .bond: return .rose
        case .etf: return .ocean
        case .stock: return .electric
        case .crypto: return .violet
        case .gold: return .amber
        case .cash: return .sage
        }
    }

    var iconName: String {
        switch self {
        case .bond:
            return "doc.text.fill"
        case .etf:
            return "chart.line.uptrend.xyaxis"
        case .stock:
            return "building.columns.fill"
        case .crypto:
            return "bitcoinsign.circle.fill"
        case .gold:
            return "circle.hexagongrid.fill"
        case .cash:
            return "banknote.fill"
        }
    }
}

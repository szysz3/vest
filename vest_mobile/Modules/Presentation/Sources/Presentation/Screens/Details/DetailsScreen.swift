import SwiftUI
import Core
import Domain

struct DetailsScreen: View {
    @StateObject var viewModel: DetailsViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.4), value: viewModel.state.isLoaded)
            .task { await viewModel.loadIfNeeded() }
            .sheet(item: sellSheetBinding) { _ in
                if let sheet = viewModel.sellSheet {
                    SellConfirmationSheet(
                        state: sheet,
                        onAmountChanged: { viewModel.sellSheet?.sellAmountText = $0 },
                        onClosePositionChanged: { viewModel.sellSheet?.closePosition = $0 },
                        onOperatorChanged: { viewModel.sellSheet?.selectedOperator = $0 },
                        onConfirm: { Task { await viewModel.confirmSell() } },
                        onCancel: { viewModel.sellSheet = nil }
                    )
                }
            }
    }

    private var sellSheetBinding: Binding<SellSheetIdentifier?> {
        Binding(
            get: {
                viewModel.sellSheet.map { SellSheetIdentifier(details: $0.details) }
            },
            set: { newValue in
                if newValue == nil {
                    viewModel.sellSheet = nil
                }
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .transition(.opacity)
        case .loaded(let state):
            DetailsContent(state: state, onSell: viewModel.requestSell)
                .transition(.opacity.combined(with: .offset(y: 12)))
        case .failed(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .transition(.opacity)
        }
    }
}

private struct SellSheetIdentifier: Identifiable, Equatable {
    let details: String
    var id: String { details }
}

private struct DetailsContent: View {
    let state: DetailsState
    let onSell: (DetailsState.Item) -> Void

    var body: some View {
        if state.sections.isEmpty {
            ScrollView {
                emptyState
            }
            .background(VestGradientBackground())
            .environment(\.colorScheme, .dark)
        } else {
            List {
                ForEach(Array(state.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                    Section {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                            DetailsItemRow(
                                item: item,
                                color: assetTone(for: section.assetType).color,
                                animationDelay: Double(sectionIndex) * 0.1 + Double(index) * 0.05
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onSell(item)
                                } label: {
                                    Label("Sell", systemImage: "arrow.down.left")
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                            .listRowSeparatorTint(Color.white.opacity(0.06))
                        }
                    } header: {
                        HStack(spacing: 10) {
                            Image(systemName: assetIcon(for: section.assetType))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(assetTone(for: section.assetType).color)
                            Text(assetTitle(for: section.assetType))
                                .font(.headline)
                                .foregroundStyle(assetTone(for: section.assetType).color)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 4, bottom: 8, trailing: 4))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(VestGradientBackground())
            .environment(\.colorScheme, .dark)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No positions yet")
                .font(.title3.weight(.semibold))
            Text("Add transactions with asset symbols to see your positions here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
        .padding(.horizontal, 40)
    }
}


private struct DetailsItemRow: View {
    let item: DetailsState.Item
    let color: Color
    var animationDelay: Double = 0
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.details)
                    .font(.headline)
            }
            Spacer()
            Text(item.totalAmount.formatted(.currency(code: "PLN")))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(animationDelay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Sell Confirmation Sheet

private struct SellConfirmationSheet: View {
    let state: SellSheetState
    let onAmountChanged: (String) -> Void
    let onClosePositionChanged: (Bool) -> Void
    let onOperatorChanged: (TransactionOperator) -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @FocusState private var amountFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header
                amountSection
                operatorSection
                closePositionSection
                if state.closePosition, let pl = state.profitOrLoss {
                    profitLossSection(pl)
                }
                confirmButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 6)
        }
        .scrollDismissesKeyboard(.immediately)
        .onTapGesture { amountFocused = false }
        .background(sheetBackground)
        .environment(\.colorScheme, .dark)
        .presentationDetents([.fraction(0.7)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sell \(state.details)")
                        .font(.title3.weight(.semibold))
                    Text("Current holding: \(state.holdingAmount.formatted(.currency(code: "PLN")))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onCancel) {
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
        SellSectionCard(title: "Sell Amount") {
            HStack(spacing: 12) {
                Text("PLN")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: Binding(
                    get: { state.sellAmountText },
                    set: { onAmountChanged($0) }
                ))
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var operatorSection: some View {
        SellSectionCard(title: "Operator") {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(state.availableOperators) { op in
                    Button {
                        onOperatorChanged(op)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(op.id == state.selectedOperator.id ? .black : .white.opacity(0.35))
                            Text(op.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(op.id == state.selectedOperator.id ? .black : .white.opacity(0.35))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(op.id == state.selectedOperator.id ? VestTone.electric.color : Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var closePositionSection: some View {
        SellSectionCard(title: "Options") {
            Toggle(isOn: Binding(
                get: { state.closePosition },
                set: { onClosePositionChanged($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Close Position")
                        .font(.subheadline.weight(.semibold))
                    Text("Fully liquidate and record profit/loss")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(VestActionColor.negative)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func profitLossSection(_ pl: Double) -> some View {
        SellSectionCard(title: "Profit / Loss") {
            HStack {
                let isProfit = pl >= 0
                let color = isProfit ? VestActionColor.positive : VestActionColor.negative
                let sign = isProfit ? "+" : ""
                Text("\(sign)\(pl.formatted(.currency(code: "PLN")))")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            HStack {
                Spacer()
                if state.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Confirm Sale")
                        .font(.headline)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(state.isValid ? VestActionColor.negative : Color.white.opacity(0.12))
            )
        }
        .disabled(!state.isValid || state.isSaving)
        .foregroundStyle(state.isValid ? .white : .secondary)
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
}

private struct SellSectionCard<Content: View>: View {
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

// MARK: - Asset Helpers

private func assetTitle(for assetType: AssetType) -> String {
    switch assetType {
    case .bond: return "Bonds"
    case .etf: return "ETF"
    case .stock: return "Stocks"
    case .crypto: return "Crypto"
    case .gold: return "Gold"
    case .cash: return "Cash"
    }
}

private func assetIcon(for assetType: AssetType) -> String {
    switch assetType {
    case .bond: return "doc.text.fill"
    case .etf: return "chart.line.uptrend.xyaxis"
    case .stock: return "building.columns.fill"
    case .crypto: return "bitcoinsign.circle.fill"
    case .gold: return "circle.hexagongrid.fill"
    case .cash: return "banknote.fill"
    }
}

private func assetTone(for assetType: AssetType) -> VestTone {
    switch assetType {
    case .bond: return .rose
    case .etf: return .ocean
    case .stock: return .electric
    case .crypto: return .violet
    case .gold: return .amber
    case .cash: return .sage
    }
}

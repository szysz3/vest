import SwiftUI
import Core
import Domain

import Factory

struct EditableFixedAsset: Identifiable {
    let id: String
    let assetType: AssetType
    let details: String
    let amount: Double
    let currency: String
}

struct DetailsScreen: View {
    @StateObject var viewModel: DetailsViewModel
    @State private var showingAddAssetSheet = false
    @State private var editingAsset: EditableFixedAsset? = nil
    @State private var deletingAssetId: String? = nil

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.4), value: viewModel.state.isLoaded)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAssetSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Add Fixed Asset")
                }
            }
            .sheet(isPresented: $showingAddAssetSheet) {
                FixedAssetSheet(
                    viewModel: Container.shared.makeFixedAssetViewModel(mode: .add),
                    onComplete: {
                        NotificationCenter.default.post(name: .portfolioDidUpdate, object: nil)
                        Task { await viewModel.load() }
                    }
                )
            }
            .sheet(item: $editingAsset) { asset in
                FixedAssetSheet(
                    viewModel: Container.shared.makeFixedAssetViewModel(
                        mode: .edit(id: asset.id),
                        assetType: asset.assetType,
                        details: asset.details,
                        amount: asset.amount,
                        currency: asset.currency
                    ),
                    onComplete: {
                        NotificationCenter.default.post(name: .portfolioDidUpdate, object: nil)
                        Task { await viewModel.load() }
                    }
                )
            }
            .alert("Delete Fixed Asset", isPresented: Binding(
                get: { deletingAssetId != nil },
                set: { if !$0 { deletingAssetId = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let id = deletingAssetId {
                        Task {
                            try? await Container.shared.deleteFixedAssetUseCase().execute(id: id)
                            NotificationCenter.default.post(name: .portfolioDidUpdate, object: nil)
                            await viewModel.load()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this fixed asset? This action cannot be undone.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .portfolioDidUpdate)) { _ in
                Task { await viewModel.load() }
            }
            .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .transition(.opacity)
        case .loaded(let state):
            DetailsContent(
                state: state,
                onEdit: { asset in editingAsset = asset },
                onDelete: { id in deletingAssetId = id },
                onAdd: { showingAddAssetSheet = true },
                onRefresh: { await viewModel.load() }
            )
            .transition(.opacity.combined(with: .offset(y: 12)))
        case .failed(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .transition(.opacity)
        }
    }
}

private struct DetailsContent: View {
    let state: DetailsState
    var onEdit: ((EditableFixedAsset) -> Void)? = nil
    var onDelete: ((String) -> Void)? = nil
    var onAdd: (() -> Void)? = nil
    var onRefresh: (() async -> Void)? = nil

    var body: some View {
        if state.sections.isEmpty {
            ScrollView {
                emptyState
            }
            .refreshable {
                await onRefresh?()
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
                                animationDelay: Double(sectionIndex) * 0.1 + Double(index) * 0.05,
                                onEdit: onEdit,
                                onDelete: onDelete
                            )
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
            .refreshable {
                await onRefresh?()
            }
            .background(VestGradientBackground())
            .environment(\.colorScheme, .dark)
            .animation(.easeOut(duration: 0.35), value: state)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No positions uploaded")
                .font(.title3.weight(.semibold))
            Text("Upload brokerage statements in the local Web Portal or add cash & gold fixed assets manually")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onAdd?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Cash or Gold")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .padding(.horizontal, 40)
    }
}


private struct DetailsItemRow: View {
    let item: DetailsState.Item
    let color: Color
    var animationDelay: Double = 0
    var onEdit: ((EditableFixedAsset) -> Void)? = nil
    var onDelete: ((String) -> Void)? = nil
    @State private var appeared = false

    private var fixedAssetId: String? {
        if let acc = item.accountNumber, acc.hasPrefix("fixed:") {
            return String(acc.dropFirst("fixed:".count))
        }
        return nil
    }

    private var isFixedAsset: Bool {
        fixedAssetId != nil
    }

    private var isProfit: Bool {
        item.profitOrLoss >= 0
    }

    private var profitColor: Color {
        isProfit ? VestActionColor.positive : VestActionColor.negative
    }

    private var profitArrowIcon: String {
        isProfit ? "arrow.up.right" : "arrow.down.right"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.details)
                            .font(.headline)

                        if isFixedAsset {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(color.opacity(0.6))
                        }
                    }
                    
                    if item.assetType == .bond, let maturity = bondMaturityLabel(for: item.details) {
                        Text("Maturity: \(maturity)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    if let acc = item.accountNumber, !acc.isEmpty, !acc.hasPrefix("fixed:") {
                        Text("Acc: \(acc)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    if item.totalAmount != item.nominalAmount && item.nominalAmount > 0 {
                        Text("Nominal: \(item.nominalAmount.formatted(.currency(code: item.currency)))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    // Primary Value in original document currency (e.g. EUR)
                    Text(item.totalAmount.formatted(.currency(code: item.currency)))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    // Primary Profit Badge in original document currency
                    if item.profitOrLoss != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: profitArrowIcon)
                                .font(.system(size: 10, weight: .bold))
                            let prefix = isProfit ? "+" : ""
                            Text("\(prefix)\(item.profitOrLoss.formatted(.currency(code: item.currency))) (\(prefix)\(String(format: "%.2f", item.profitOrLossPct))%)")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(profitColor)
                    }

                    // Less emphasized PLN converted value (if non-PLN currency)
                    if item.currency.uppercased() != "PLN" {
                        let prefix = isProfit ? "+" : ""
                        Text("≈ \(item.totalAmountPLN.formatted(.currency(code: "PLN"))) (\(prefix)\(item.profitOrLossPLN.formatted(.currency(code: "PLN")))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if let fixedId = fixedAssetId {
                onEdit?(EditableFixedAsset(
                    id: fixedId,
                    assetType: item.assetType,
                    details: item.details,
                    amount: item.totalAmount,
                    currency: item.currency
                ))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let fixedId = fixedAssetId {
                Button(role: .destructive) {
                    onDelete?(fixedId)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    onEdit?(EditableFixedAsset(
                        id: fixedId,
                        assetType: item.assetType,
                        details: item.details,
                        amount: item.totalAmount,
                        currency: item.currency
                    ))
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(color)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(animationDelay)) {
                appeared = true
            }
        }
    }
}


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

private func bondMaturityLabel(for details: String) -> String? {
    let upper = details.uppercased()
    let pattern = #"([A-Z]{2,4})\s*(\d{2})(\d{2})"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: upper, options: [], range: NSRange(location: 0, length: upper.utf16.count)) {
        if let mmRange = Range(match.range(at: 2), in: upper),
           let yyRange = Range(match.range(at: 3), in: upper),
           let mm = Int(upper[mmRange]),
           let yy = Int(upper[yyRange]),
           (1...12).contains(mm) {
            return String(format: "%02d.20%02d", mm, yy)
        }
    }
    return nil
}

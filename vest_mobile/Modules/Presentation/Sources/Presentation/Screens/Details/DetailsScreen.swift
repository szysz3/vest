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
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .transition(.opacity)
        case .loaded(let state):
            DetailsContent(state: state)
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
            Text("Upload brokerage statements in the local Web Portal to see your detailed holdings here")
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
                    Text(item.details)
                        .font(.headline)
                    
                    if item.assetType == .bond, let maturity = bondMaturityLabel(for: item.details) {
                        Text("Maturity: \(maturity)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    if let acc = item.accountNumber, !acc.isEmpty {
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

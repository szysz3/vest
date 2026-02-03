import SwiftUI
import Core

struct PortfolioScreen: View {
    @StateObject var viewModel: PortfolioViewModel
    @State private var isAddSheetPresented = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.4), value: viewModel.state.isLoaded)
            .task {
                await viewModel.loadIfNeeded()
                await viewModel.loadFormOptionsIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addTransactionToolbarButton
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .transition(.opacity)
        case .loaded(let state):
            PortfolioContent(state: state)
                .transition(.opacity.combined(with: .offset(y: 12)))
                .sheet(isPresented: $isAddSheetPresented) {
                    AddTransactionSheet(
                        options: viewModel.formOptions,
                        onSave: { draft in
                            try await viewModel.addTransaction(
                                amount: draft.amount,
                                action: draft.action,
                                assetType: draft.assetType,
                                operatorName: draft.operatorName,
                                details: draft.details
                            )
                        }
                    )
                }
        case .failed(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .transition(.opacity)
        }
    }

    private func presentAddTransaction() {
        if viewModel.formOptions.isEmpty {
            Task {
                await viewModel.loadFormOptionsIfNeeded()
                await MainActor.run {
                    if !viewModel.formOptions.isEmpty {
                        isAddSheetPresented = true
                    }
                }
            }
        } else {
            isAddSheetPresented = true
        }
    }

    private var addTransactionToolbarButton: some View {
        Button(action: presentAddTransaction) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VestActionColor.positive)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(VestActionColor.positive.opacity(0.18))
                )
        }
        .buttonStyle(ScaleToolbarButtonStyle())
    }

}

private struct ScaleToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct PortfolioContent: View {
    let state: PortfolioState
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            if state.assets.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    chartCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    assetsSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
        .background(VestGradientBackground())
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No holdings yet")
                .font(.title3.weight(.semibold))
            Text("Tap + to add your first transaction")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private var chartCard: some View {
        VStack {
            PortfolioPieChart(assets: state.assets, totalAmount: state.totalAmount)
                .frame(width: 280, height: 280)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(VestCardBackground())
    }

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Holdings")
                .font(.title3.weight(.semibold))

            ForEach(Array(state.assets.enumerated()), id: \.element.id) { index, asset in
                AssetRow(
                    asset: asset,
                    totalAmount: state.totalAmount,
                    animationDelay: Double(index) * 0.06
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct PortfolioPieChart: View {
    let assets: [PortfolioState.Asset]
    let totalAmount: Double
    @State private var chartProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 34)
                .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)

            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.start * chartProgress, to: segment.end * chartProgress)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: 34, lineCap: .round)
                    )
                    .shadow(color: segment.color.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .rotationEffect(.degrees(-90))

            formattedAmount
                .opacity(chartProgress)
        }
        .padding(10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                chartProgress = 1
            }
        }
    }

    private var formattedAmount: some View {
        let whole = Int(totalAmount)
        let fraction = totalAmount - Double(whole)
        let fractionText = String(format: "%02d", Int((fraction * 100).rounded()))

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(whole)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(",\(fractionText) PLN")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var segments: [ChartSegment] {
        var current: Double = 0
        let gap = 0.006
        return assets.map { asset in
            let fraction = max(asset.amount / max(totalAmount, 1), 0)
            let trimmed = max(fraction - gap, 0.002)
            let start = current
            let end = min(current + trimmed, 1)
            current = min(current + fraction, 1)
            return ChartSegment(start: start, end: end, color: asset.color.color)
        }
    }

    private struct ChartSegment {
        let start: Double
        let end: Double
        let color: Color
    }
}

private struct AssetRow: View {
    let asset: PortfolioState.Asset
    let totalAmount: Double
    var animationDelay: Double = 0
    @State private var appeared = false

    private var percent: Double {
        guard totalAmount > 0 else { return 0 }
        return asset.amount / totalAmount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(asset.color.color.opacity(0.18))
                    Image(systemName: asset.icon)
                        .foregroundStyle(asset.color.color)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(.headline)
                    Text(asset.amount.formatted(.currency(code: "PLN")))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(percent.formatted(.percent.precision(.fractionLength(1))))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            AllocationBar(value: appeared ? percent : 0, color: asset.color.color)
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(0.3 + animationDelay)) {
                appeared = true
            }
        }
    }
}

private struct AllocationBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width * value, value > 0 ? 8 : 0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: width)
                    .animation(.easeOut(duration: 0.6), value: width)
            }
        }
        .frame(height: 8)
    }
}

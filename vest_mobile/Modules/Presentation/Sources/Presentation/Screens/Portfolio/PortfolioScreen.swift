import SwiftUI
import Core
import Domain

struct PortfolioScreen: View {
    @StateObject var viewModel: PortfolioViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.4), value: viewModel.state.isLoaded)
            .task {
                await viewModel.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .transition(.opacity)
        case .loaded(let state):
            PortfolioContent(state: state, syncStatus: viewModel.syncStatus)
                .transition(.opacity.combined(with: .offset(y: 12)))
        case .failed(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .transition(.opacity)
        }
    }
}

private struct PortfolioContent: View {
    let state: PortfolioState
    let syncStatus: StatementSyncStatus?
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if let syncStatus = syncStatus {
                    SyncStatusBanner(status: syncStatus)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                }

                if state.assets.isEmpty {
                    emptyState
                } else {
                    chartCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    assetsSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
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
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No statement data yet")
                .font(.title3.weight(.semibold))
            Text("Upload brokerage statements via the local Web Portal to populate portfolio summary")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var chartCard: some View {
        VStack {
            PortfolioPieChart(
                assets: state.assets,
                totalAmount: state.totalAmount,
                nominalAmount: state.nominalAmount,
                profitOrLoss: state.profitOrLoss,
                profitOrLossPct: state.profitOrLossPct
            )
            .frame(width: 280, height: 280)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(VestCardBackground())
    }

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Aggregated Holdings")
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

private struct SyncStatusBanner: View {
    let status: StatementSyncStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.allUploaded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(status.allUploaded ? VestActionColor.positive : Color.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.allUploaded ? "All Statements Up to Date" : "Pending Statement Uploads")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                if status.allUploaded {
                    Text("\(status.uploadedCount)/\(status.totalCount) Statements Active • Synced \(status.lastSyncDate ?? "")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("\(status.uploadedCount)/\(status.totalCount) Uploaded. Missing: \(status.missingSlots.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(status.allUploaded ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(status.allUploaded ? Color.green.opacity(0.25) : Color.orange.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private struct PortfolioPieChart: View {
    let assets: [PortfolioState.Asset]
    let totalAmount: Double
    let nominalAmount: Double
    let profitOrLoss: Double
    let profitOrLossPct: Double
    @State private var chartProgress: Double = 0

    private var mainDisplayAmount: Double {
        nominalAmount > 0 ? nominalAmount : totalAmount
    }

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

            VStack(spacing: 4) {
                formattedAmount

                if profitOrLoss != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: profitOrLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        let prefix = profitOrLoss >= 0 ? "+" : ""
                        Text("\(prefix)\(profitOrLoss.formatted(.currency(code: "PLN"))) (\(prefix)\(String(format: "%.2f", profitOrLossPct))%)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(profitOrLoss >= 0 ? VestActionColor.positive : VestActionColor.negative)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((profitOrLoss >= 0 ? VestActionColor.positive : VestActionColor.negative).opacity(0.15))
                    )
                }
            }
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
        let whole = Int(mainDisplayAmount)
        let fraction = mainDisplayAmount - Double(whole)
        let fractionText = String(format: "%02d", Int((fraction * 100).rounded()))

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(whole)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(",\(fractionText) PLN")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var segments: [ChartSegment] {
        var current: Double = 0
        let gap = 0.006
        let total = max(totalAmount, 1)
        return assets.map { asset in
            let fraction = max(asset.amount / total, 0)
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

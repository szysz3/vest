import SwiftUI
import Core

struct PortfolioScreen: View {
    @StateObject var viewModel: PortfolioViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded(let state):
            PortfolioContent(state: state)
        case .failed(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PortfolioContent: View {
    let state: PortfolioState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                chartCard
                assetsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(PortfolioBackground())
        .environment(\.colorScheme, .dark)
    }

    private var chartCard: some View {
        VStack {
            PortfolioPieChart(assets: state.assets, totalAmount: state.totalAmount)
                .frame(width: 280, height: 280)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(PortfolioCardBackground())
    }

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Holdings")
                .font(.title3.weight(.semibold))

            ForEach(state.assets) { asset in
                AssetRow(
                    asset: asset,
                    totalAmount: state.totalAmount
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PortfolioCardBackground())
    }
}

private struct PortfolioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.12),
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.16, green: 0.18, blue: 0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.22, green: 0.46, blue: 0.78).opacity(0.35))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 140, y: -220)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color(red: 0.90, green: 0.66, blue: 0.44).opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 30)
                .offset(x: -160, y: 260)
        }
    }
}

private struct PortfolioCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct PortfolioPieChart: View {
    let assets: [PortfolioState.Asset]
    let totalAmount: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 34)
                .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)

            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: 34, lineCap: .round)
                    )
                    .shadow(color: segment.color.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .rotationEffect(.degrees(-90))

            Text(totalAmount.formatted(.currency(code: "USD")))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(10)
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
            return ChartSegment(start: start, end: end, color: asset.color.swiftUIColor)
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

    private var percent: Double {
        guard totalAmount > 0 else { return 0 }
        return asset.amount / totalAmount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(asset.color.swiftUIColor.opacity(0.18))
                    Image(systemName: asset.icon)
                        .foregroundStyle(asset.color.swiftUIColor)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(.headline)
                    Text(asset.amount.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(percent.formatted(.percent.precision(.fractionLength(1))))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            AllocationBar(value: percent, color: asset.color.swiftUIColor)
        }
    }
}

private struct AllocationBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width * value, 8)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: width)
            }
        }
        .frame(height: 8)
    }
}

private extension PortfolioState.AssetColor {
    var swiftUIColor: Color {
        switch self {
        case .electric:
            return Color(red: 0.44, green: 0.70, blue: 1.00)
        case .mint:
            return Color(red: 0.37, green: 0.86, blue: 0.74)
        case .sunset:
            return Color(red: 1.00, green: 0.62, blue: 0.43)
        case .violet:
            return Color(red: 0.70, green: 0.56, blue: 1.00)
        case .ocean:
            return Color(red: 0.33, green: 0.61, blue: 0.94)
        case .sand:
            return Color(red: 0.95, green: 0.83, blue: 0.58)
        }
    }
}

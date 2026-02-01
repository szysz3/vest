import SwiftUI
import Core

struct HistoryScreen: View {
    @StateObject var viewModel: HistoryViewModel

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
            HistoryContent(state: state)
        case .failed(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HistoryContent: View {
    let state: HistoryState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                transactionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(HistoryBackground())
        .environment(\.colorScheme, .dark)
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(state.transactions) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
    }
}

private struct TransactionRow: View {
    let transaction: HistoryState.Transaction

    private var accentColor: Color {
        transaction.assetType.tone.swiftUIColor
    }

    private var actionColor: Color {
        switch transaction.action {
        case .bought:
            return Color(red: 0.37, green: 0.86, blue: 0.74)
        case .sold:
            return Color(red: 1.00, green: 0.62, blue: 0.43)
        }
    }

    private var dateText: String {
        transaction.date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(actionColor.opacity(0.18))
                Image(systemName: transaction.assetType.icon)
                    .foregroundStyle(actionColor)
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(transaction.action.title)
                        .font(.headline)
                        .foregroundStyle(actionColor)
                    Spacer()
                    Text(transaction.amount.formatted(.currency(code: "USD")))
                        .font(.headline.weight(.semibold))
                }

                Text(transaction.name)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    assetTypePill

                    Text(transaction.place)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(dateText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(HistoryRowBackground())
    }

    private var assetTypePill: some View {
        Text(transaction.assetType.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.18))
            )
    }
}

private struct HistoryBackground: View {
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
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: 140, y: -240)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color(red: 0.90, green: 0.66, blue: 0.44).opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 30)
                .offset(x: -160, y: 260)
        }
    }
}

private struct HistoryRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

private extension HistoryState.TransactionTone {
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

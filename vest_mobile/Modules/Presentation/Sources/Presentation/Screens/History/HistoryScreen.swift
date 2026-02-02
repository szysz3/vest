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
            if state.transactions.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    transactionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
        .background(VestGradientBackground())
        .environment(\.colorScheme, .dark)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No transactions yet")
                .font(.title3.weight(.semibold))
            Text("Your transaction history will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
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
        transaction.assetType.tone.color
    }

    private var actionColor: Color {
        switch transaction.action {
        case .bought, .cashDeposit:
            return VestActionColor.positive
        case .sold, .cashWithdrawal:
            return VestActionColor.negative
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
                    Text(transaction.amount.formatted(.currency(code: "PLN")))
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
        .background(VestCardBackground(cornerRadius: 18, fillOpacity: 0.04, strokeOpacity: 0.06))
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

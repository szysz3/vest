import SwiftUI
import Core

struct HistoryScreen: View {
    @StateObject var viewModel: HistoryViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.4), value: viewModel.state.isLoaded)
            .task {
                viewModel.bind()
                await viewModel.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .transition(.opacity)
        case .loaded:
            HistoryContent(viewModel: viewModel)
                .transition(.opacity.combined(with: .offset(y: 12)))
        case .failed(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .transition(.opacity)
        }
    }
}

private struct HistoryContent: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            if viewModel.displayTransactions.isEmpty && viewModel.viewMode == .all {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    filtersSection
                    if viewModel.viewMode == .filtered {
                        filteredSummarySection
                    }
                    if viewModel.displayTransactions.isEmpty {
                        filteredEmptyState
                    } else {
                        transactionsSection(viewModel.displayTransactions)
                    }
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

    private func transactionsSection(_ transactions: [HistoryState.Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                TransactionRow(transaction: transaction, animationDelay: Double(index) * 0.05)
            }
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("History Filters")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.resetFilters()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }

            Picker("View", selection: $viewModel.viewMode) {
                ForEach(HistoryViewMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $viewModel.filters.closedOnly) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Closed positions only")
                        .font(.subheadline.weight(.semibold))
                    Text("Show only position closed entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(VestActionColor.negative)

            Toggle(isOn: $viewModel.filters.dateRangeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Filter by date range")
                        .font(.subheadline.weight(.semibold))
                    Text("Limit results to a specific period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(VestActionColor.positive)

            if viewModel.filters.dateRangeEnabled {
                VStack(spacing: 10) {
                    datePickerRow(title: "From", selection: $viewModel.filters.startDate)
                    datePickerRow(title: "To", selection: $viewModel.filters.endDate)
                }
            }
        }
        .padding(16)
        .background(VestCardBackground(cornerRadius: 18, fillOpacity: 0.06, strokeOpacity: 0.08))
    }

    private func datePickerRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker(
                "",
                selection: selection,
                in: viewModel.availableDateRange,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }

    private var filteredSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filtered Summary")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.filteredResult.transactions.count) entries")
                        .font(.subheadline.weight(.semibold))
                    Text("Matching filters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Net P/L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.filteredResult.profitLossText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(filteredProfitLossColor)
                }
            }
        }
        .padding(16)
        .background(VestCardBackground(cornerRadius: 18, fillOpacity: 0.06, strokeOpacity: 0.08))
    }

    private var filteredProfitLossColor: Color {
        viewModel.filteredResult.profitLoss >= 0 ? VestActionColor.positive : VestActionColor.negative
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 8) {
            Text("No entries match your filters")
                .font(.subheadline.weight(.semibold))
            Text("Adjust filters to see more history")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct TransactionRow: View {
    let transaction: HistoryState.Transaction
    var animationDelay: Double = 0
    @State private var appeared = false

    private var accentColor: Color {
        transaction.assetType.tone.color
    }

    private var actionColor: Color {
        switch transaction.action {
        case .bought, .cashDeposit:
            return VestActionColor.positive
        case .sold, .cashWithdrawal, .positionClosed:
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

                if transaction.action == .positionClosed, let pl = transaction.profitOrLoss {
                    HStack(spacing: 6) {
                        let isProfit = pl >= 0
                        let plColor = isProfit ? VestActionColor.positive : VestActionColor.negative
                        let sign = isProfit ? "+" : ""
                        Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(plColor)
                        Text("\(sign)\(pl.formatted(.currency(code: "PLN")))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(plColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill((pl >= 0 ? VestActionColor.positive : VestActionColor.negative).opacity(0.15))
                    )
                }

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
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(animationDelay)) {
                appeared = true
            }
        }
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

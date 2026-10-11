import SwiftUI
import Charts
import Core
import Domain

public struct HistoryScreen: View {
    @StateObject var viewModel: HistoryViewModel

    public init(viewModel: HistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.4), value: viewModel.state.isLoaded)
            .onReceive(NotificationCenter.default.publisher(for: .portfolioDidUpdate)) { _ in
                Task { await viewModel.load() }
            }
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
            HistoryContent(
                state: state,
                selectedRange: $viewModel.selectedRange,
                savingsMode: $viewModel.savingsMode,
                selectedDate: $viewModel.selectedDate,
                selectedSavingId: $viewModel.selectedSavingId,
                onRefresh: { await viewModel.load() }
            )
            .transition(.opacity.combined(with: .offset(y: 12)))
        case .failed(let error):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .transition(.opacity)
        }
    }
}

private struct HistoryContent: View {
    let state: HistoryState
    @Binding var selectedRange: TimeRange
    @Binding var savingsMode: SavingsMode
    @Binding var selectedDate: Date?
    @Binding var selectedSavingId: String?
    var onRefresh: (() async -> Void)? = nil
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Balance & Growth Banner
                HeroSavingsCard(state: state, selectedRange: selectedRange)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                // Dual KPI Cards: Monthly & Yearly Rate
                KPISavingsRow(state: state)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                // Main Savings Evolution Chart ("Before and Now")
                TimelineChartCard(
                    state: state,
                    selectedRange: $selectedRange,
                    selectedDate: $selectedDate
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 25)

                // Savings Contribution Breakdown Bar Chart
                ContributionsChartCard(
                    state: state,
                    savingsMode: $savingsMode,
                    selectedSavingId: $selectedSavingId
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)

                // History Log List
                HistoryLogCard(state: state)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 35)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .refreshable {
            await onRefresh?()
        }
        .background(VestGradientBackground())
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

// MARK: - Hero Savings Card ("Before and Now")
private struct HeroSavingsCard: View {
    let state: HistoryState
    let selectedRange: TimeRange

    private var delta: RangeDelta {
        state.delta(for: selectedRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Total Savings Balance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                let currentVal = delta.endAmount
                let whole = Int(currentVal)
                let fraction = currentVal - Double(whole)
                let fractionText = String(format: "%02d", Int((fraction * 100).rounded()))

                Text("\(whole)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(",\(fractionText) PLN")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                if state.hasMultipleSnapshots && delta.changeAmount != 0 {
                    GrowthBadge(changeAmount: delta.changeAmount, changePct: delta.changePct)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                if state.hasMultipleSnapshots && delta.startAmount != delta.endAmount {
                    Text("\(delta.rangeLabel) • Started at \(Int(delta.startAmount)) PLN")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("Current status quo • 1 snapshot recorded")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct GrowthBadge: View {
    let changeAmount: Double
    let changePct: Double

    var body: some View {
        let isPositive = changeAmount >= 0
        let color = isPositive ? VestActionColor.positive : VestActionColor.negative
        let prefix = isPositive ? "+" : ""

        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .bold))
            Text("\(prefix)\(Int(changeAmount)) PLN (\(prefix)\(String(format: "%.1f", changePct))%)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.16))
        )
    }
}

// MARK: - Dual KPI Cards: Monthly & Yearly Savings
private struct KPISavingsRow: View {
    let state: HistoryState

    var body: some View {
        HStack(spacing: 14) {
            // Monthly Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VestTone.mint.color)
                    Text("Monthly Savings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Text("\(Int(state.summary.currentMonthSaved)) PLN")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(state.hasMultipleSnapshots ? "Avg: \(Int(state.monthlyAverage)) PLN/mo" : "Baseline month")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VestCardBackground())

            // Yearly Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VestTone.ocean.color)
                    Text("Yearly Savings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Text("\(Int(state.summary.currentYearSaved)) PLN")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(state.hasMultipleSnapshots ? "Past 12 months" : "Baseline year")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VestCardBackground())
        }
    }
}

// MARK: - Primary Timeline Chart ("Before and Now")
private struct TimelineChartCard: View {
    let state: HistoryState
    @Binding var selectedRange: TimeRange
    @Binding var selectedDate: Date?

    private var points: [PortfolioSnapshotPoint] {
        state.filteredSnapshots(for: selectedRange)
    }

    private var activePoint: PortfolioSnapshotPoint? {
        guard let sel = selectedDate else { return points.last }
        return points.min(by: { abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel)) })
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.totalAmount)
        let minVal = (values.min() ?? 0) * 0.95
        let maxVal = (values.max() ?? 1000) * 1.05
        return minVal...maxVal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with interactive callout or title
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Savings Trajectory")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if let active = activePoint {
                        Text("\(active.dateString) • \(Int(active.totalAmount)) PLN")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VestActionColor.positive)
                    } else {
                        Text("Historical portfolio value over time")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Spacer()

                // Range picker
                TimeRangePicker(selectedRange: $selectedRange)
            }

            // Swift Charts Line & Area
            if points.count >= 2 {
                Chart {
                    ForEach(points) { pt in
                        AreaMark(
                            x: .value("Date", pt.date),
                            yStart: .value("Baseline", yDomain.lowerBound),
                            yEnd: .value("Value", pt.totalAmount)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    VestActionColor.positive.opacity(0.28),
                                    VestActionColor.positive.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Value", pt.totalAmount)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(VestActionColor.positive)
                    }

                    if let active = activePoint {
                        RuleMark(x: .value("Selected Date", active.date))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.6))

                        PointMark(
                            x: .value("Date", active.date),
                            y: .value("Value", active.totalAmount)
                        )
                        .symbolSize(80)
                        .foregroundStyle(VestActionColor.positive)
                        .annotation(position: .top, spacing: 8) {
                            Text("\(Int(active.totalAmount)) PLN")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.75)))
                                .overlay(Capsule().stroke(VestActionColor.positive.opacity(0.4), lineWidth: 1))
                        }
                    }
                }
                .chartYScale(domain: yDomain)
                .chartPlotStyle { plotArea in
                    plotArea.clipped()
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.white.opacity(0.08))
                        if let amount = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(amount / 1000))k")
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                    }
                }
                .frame(height: 220)
                .clipped()
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let plotFrame: CGRect
                                        #if os(macOS)
                                        if #available(macOS 14.0, *) {
                                            guard let frame = proxy.plotFrame else { return }
                                            plotFrame = geo[frame]
                                        } else {
                                            plotFrame = geo[proxy.plotAreaFrame]
                                        }
                                        #else
                                        guard let frame = proxy.plotFrame else { return }
                                        plotFrame = geo[frame]
                                        #endif

                                        guard plotFrame.contains(value.location) else {
                                            selectedDate = nil
                                            return
                                        }

                                        let locationX = value.location.x - plotFrame.origin.x
                                        if let date: Date = proxy.value(atX: locationX) {
                                            selectedDate = date
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedDate = nil
                                    }
                            )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(VestActionColor.positive.opacity(0.7))
                    Text("Tracking Started")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Baseline snapshot recorded at \(Int(points.first?.totalAmount ?? state.summary.currentTotal)) PLN. As you upload monthly statements, your historical savings curve will appear here.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct TimeRangePicker: View {
    @Binding var selectedRange: TimeRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selectedRange == range ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? Color.white.opacity(0.18) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Contributions Bar Chart (Monthly vs Yearly)
private struct ContributionsChartCard: View {
    let state: HistoryState
    @Binding var savingsMode: SavingsMode
    @Binding var selectedSavingId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Savings Contributions")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Net savings added per period")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                // Mode picker
                Picker("Mode", selection: $savingsMode) {
                    ForEach(SavingsMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            if savingsMode == .monthly {
                MonthlyBarChart(
                    items: state.monthlySavings,
                    average: state.monthlyAverage,
                    selectedId: $selectedSavingId
                )
            } else {
                YearlyBarChart(
                    items: state.yearlySavings,
                    average: state.yearlyAverage,
                    selectedId: $selectedSavingId
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct MonthlyBarChart: View {
    let items: [MonthlySaving]
    let average: Double
    @Binding var selectedId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(items) { item in
                    BarMark(
                        x: .value("Month", item.shortLabel),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(
                        item.id == selectedId
                            ? VestActionColor.positive
                            : VestActionColor.positive.opacity(0.75)
                    )
                    .cornerRadius(6)
                }

                if average > 0 {
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(VestTone.amber.color.opacity(0.8))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg \(Int(average))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(VestTone.amber.color)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.white.opacity(0.08))
                    if let val = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(val / 1000))k")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .frame(height: 180)
        }
    }
}

private struct YearlyBarChart: View {
    let items: [YearlySaving]
    let average: Double
    @Binding var selectedId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(items) { item in
                    BarMark(
                        x: .value("Year", item.label),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(
                        item.id == selectedId
                            ? VestTone.ocean.color
                            : VestTone.ocean.color.opacity(0.8)
                    )
                    .cornerRadius(8)
                }

                if average > 0 {
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(VestTone.amber.color.opacity(0.8))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg \(Int(average))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(VestTone.amber.color)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.white.opacity(0.08))
                    if let val = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(val / 1000))k")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .frame(height: 180)
        }
    }
}

// MARK: - History Log Card
private struct HistoryLogCard: View {
    let state: HistoryState

    private var recentSnapshots: [PortfolioSnapshotPoint] {
        Array(state.snapshots.suffix(12).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("History Log")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(state.snapshots.count) periods")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            ForEach(recentSnapshots) { pt in
                HistoryLogRow(point: pt, isLast: pt.id == recentSnapshots.last?.id)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct HistoryLogRow: View {
    let point: PortfolioSnapshotPoint
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(VestActionColor.positive.opacity(0.2))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(point.dateString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Saved: +\(Int(point.amountSaved)) PLN")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Text("\(Int(point.totalAmount)) PLN")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.vertical, 6)

            if !isLast {
                Divider().overlay(Color.white.opacity(0.08))
            }
        }
    }
}

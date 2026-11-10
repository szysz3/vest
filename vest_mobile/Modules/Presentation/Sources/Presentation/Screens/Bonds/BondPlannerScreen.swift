import SwiftUI
import Charts
import Core
import Domain

public struct BondPlannerScreen: View {
    @StateObject var viewModel: BondPlannerViewModel

    public init(viewModel: BondPlannerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.35), value: viewModel.state.isLoaded)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.isShowingSettingsSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Configure Bond Planner")
                }
            }
            .sheet(isPresented: $viewModel.isShowingSettingsSheet) {
                BondPlannerSettingsSheet(viewModel: viewModel)
            }
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VestGradientBackground())
                .transition(.opacity)
        case .loaded(let data):
            BondPlannerContent(
                data: data,
                selectedReferenceMonth: viewModel.selectedReferenceMonth ?? data.market.issueMonth,
                selectedContinuityYear: $viewModel.selectedContinuityYear,
                selectedCalendarCellId: $viewModel.selectedCalendarCellId,
                onSelectMonth: { m in Task { await viewModel.selectReferenceMonth(m) } },
                onSelectHorizon: { h in Task { await viewModel.selectHorizonYears(h) } },
                onToggleFamily: { f in Task { await viewModel.toggleFamilyBonds(f) } },
                onOpenSettings: { viewModel.isShowingSettingsSheet = true },
                onRefresh: { await viewModel.load() }
            )
            .transition(.opacity.combined(with: .offset(y: 10)))
        case .failed(let error):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VestGradientBackground())
            .transition(.opacity)
        }
    }
}

private struct BondPlannerContent: View {
    let data: BondPlannerData
    let selectedReferenceMonth: Int
    @Binding var selectedContinuityYear: Int?
    @Binding var selectedCalendarCellId: String?
    var onSelectMonth: (Int) -> Void
    var onSelectHorizon: (Int) -> Void
    var onToggleFamily: (Bool) -> Void
    var onOpenSettings: () -> Void
    var onRefresh: () async -> Void

    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Hero Config & Market Conditions Banner
                PlannerHeaderCard(
                    data: data,
                    selectedMonth: selectedReferenceMonth,
                    onSelectMonth: onSelectMonth,
                    onSelectHorizon: onSelectHorizon,
                    onToggleFamily: onToggleFamily,
                    onOpenSettings: onOpenSettings
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                // 2. Consolidated Purchase Recommendations ("What to Buy Now")
                PurchaseRecommendationCard(
                    data: data,
                    onOpenSettings: onOpenSettings
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // 3. Stacked Bar Chart: Target Month Continuity Across Upcoming Years
                ContinuityChartCard(
                    data: data,
                    selectedYear: $selectedContinuityYear
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // 4. Year-by-Year Continuity & Best Bond Comparison
                YearlySlotsComparisonCard(
                    data: data,
                    selectedYear: $selectedContinuityYear
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                // 5. 12-Month x Multi-Year Continuity Heatmap Grid
                MaturityHeatmapCard(
                    data: data,
                    selectedCellId: $selectedCalendarCellId
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 28)

                // 6. Early Termination ("Przedterminowy Wykup") Advisor
                EarlyRedemptionAdvisorCard(
                    recommendations: data.earlyRedemptionRecommendations,
                    targetMonthlyNominal: data.settings.targetMonthlyNominal
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 32)

                // 7. Current "List Emisyjny" Reference Table
                ListEmisyjnyCard(market: data.market)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .refreshable {
            await onRefresh()
        }
        .background(VestGradientBackground())
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                appeared = true
            }
        }
    }
}

// MARK: - 1. Header Card (Target, Budget, Live CPI & NBP, Month Selector)
private struct PlannerHeaderCard: View {
    let data: BondPlannerData
    let selectedMonth: Int
    var onSelectMonth: (Int) -> Void
    var onSelectHorizon: (Int) -> Void
    var onToggleFamily: (Bool) -> Void
    var onOpenSettings: () -> Void

    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private let horizonOptions = [3, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VestTone.rose.color)
                        Text("BOND CASH FLOW CONTINUITY")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(VestTone.rose.color)
                    }

                    Text("Target: \(Int(data.settings.targetMonthlyNominal)) PLN / mo")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: onOpenSettings) {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.caption2.weight(.bold))
                        Text("Edit Plan")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            // KPI Pills: Budget, CPI Inflation, NBP Rate, Held Bonds
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    MacroBadge(
                        icon: "banknote.fill",
                        label: "Budget",
                        value: "\(Int(data.settings.investmentBudget)) PLN",
                        color: VestActionColor.positive
                    )
                    MacroBadge(
                        icon: "flame.fill",
                        label: data.settings.customInflationRatePct != nil ? "CPI (Custom)" : "CPI Inflation",
                        value: String(format: "%.2f%%", data.market.effectiveInflationRatePct),
                        color: VestTone.amber.color
                    )
                    MacroBadge(
                        icon: "percent",
                        label: data.settings.customNbpRatePct != nil ? "NBP (Custom)" : "NBP Rate",
                        value: String(format: "%.2f%%", data.market.effectiveNbpReferenceRatePct),
                        color: VestTone.ocean.color
                    )
                    MacroBadge(
                        icon: "doc.text.fill",
                        label: "Held Bonds",
                        value: "\(Int(data.summary.totalHeldBondsNominalPLN)) PLN",
                        color: VestTone.rose.color
                    )
                }
            }

            Divider().overlay(Color.white.opacity(0.08))

            // Target Month Selector
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Target Maturity Month")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    // Horizon quick picker
                    HStack(spacing: 4) {
                        ForEach(horizonOptions, id: \.self) { h in
                            Button {
                                onSelectHorizon(h)
                            } label: {
                                Text("\(h)Y")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(data.settings.horizonYears == h ? .white : .white.opacity(0.55))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(data.settings.horizonYears == h ? VestTone.rose.color.opacity(0.45) : Color.white.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(1...12, id: \.self) { m in
                            let isSelected = m == selectedMonth
                            Button {
                                onSelectMonth(m)
                            } label: {
                                Text(monthNames[m - 1])
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(
                                            isSelected
                                                ? VestTone.electric.color.opacity(0.45)
                                                : Color.white.opacity(0.05)
                                        )
                                    )
                                    .overlay(
                                        Capsule().stroke(
                                            isSelected ? VestTone.electric.color.opacity(0.8) : Color.clear,
                                            lineWidth: 1
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Family Bonds 800+ Toggle
            HStack {
                Text("Include Family Bonds 800+ (ROS 6Y / ROD 12Y)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { data.settings.includeFamilyBonds },
                    set: { onToggleFamily($0) }
                ))
                .labelsHidden()
                .tint(VestTone.rose.color)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct MacroBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - 2. Consolidated Purchase Recommendation Card
private struct PurchaseRecommendationCard: View {
    let data: BondPlannerData
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VestActionColor.positive)
                        Text("RECOMMENDED TO BUY (\(data.market.issueMonthLabel))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(VestActionColor.positive)
                    }
                    Text("Best Bonds from List Emisyjny")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Est. Net Profit")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("+\(Int(data.summary.projectedTotalNetProfitFromBudgetPLN)) PLN")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VestActionColor.positive)
                }
            }

            // Continuity vs Surplus Budget Breakdown Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Min Continuity Needed")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("\(Int(data.summary.totalRequiredForContinuityPLN)) PLN")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                Divider().frame(height: 24).overlay(Color.white.opacity(0.1))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allocated to Continuity")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("\(Int(data.summary.budgetAllocatedToContinuityPLN)) PLN")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VestTone.electric.color)
                }
                if data.summary.budgetAllocatedToSurplusPLN > 0 {
                    Divider().frame(height: 24).overlay(Color.white.opacity(0.1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Surplus Invested")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                        Text("+\(Int(data.summary.budgetAllocatedToSurplusPLN)) PLN")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VestTone.amber.color)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )

            if data.purchaseRecommendations.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(VestActionColor.positive)
                    Text(data.settings.investmentBudget < 100
                         ? "Set an investment budget (>= 100 PLN) in Edit Plan to generate bond purchase recommendations."
                         : "All target months in this horizon are already 100% covered!")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.vertical, 6)
            } else {
                ForEach(data.purchaseRecommendations) { rec in
                    PurchaseRecommendationRow(rec: rec)
                }
            }

            if data.summary.unfundedContinuityGapPLN > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(VestTone.amber.color)
                    Text("Remaining continuity gap across \(data.settings.horizonYears) years: \(Int(data.summary.unfundedContinuityGapPLN)) PLN (increase budget or use early redemption below).")
                        .font(.caption2)
                        .foregroundStyle(VestTone.amber.color.opacity(0.95))
                }
                .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct PurchaseRecommendationRow: View {
    let rec: BondPurchaseRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(rec.bondCode)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(rec.totalUnits) bonds")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VestTone.rose.color.opacity(0.25)))
                            .foregroundStyle(VestTone.rose.color)
                    }
                    Text("\(rec.bondName) • 1st yr \(String(format: "%.2f%%", rec.firstYearRatePct))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(rec.totalNominalPLN)) PLN")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("+\(Int(rec.projectedTotalNetProfitPLN)) PLN net (\(String(format: "%.2f%%", rec.effectiveAnnualRatePct))/yr)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(VestActionColor.positive)
                }
            }

            // Allocation pills showing which target dates this purchase covers
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(rec.allocations) { alloc in
                        HStack(spacing: 4) {
                            Image(systemName: alloc.isSurplus ? "plus.circle.fill" : (alloc.isEarlyRedemption ? "scissors" : "calendar.badge.checkmark"))
                                .font(.system(size: 9, weight: .bold))
                            if alloc.isSurplus {
                                Text("Surplus: \(Int(alloc.nominalPLN)) PLN (hold \(alloc.holdingYears)y to \(alloc.targetLabel))")
                            } else if alloc.isEarlyRedemption {
                                Text("For \(alloc.targetLabel): \(Int(alloc.nominalPLN)) PLN (early exit after \(alloc.holdingYears)y)")
                            } else {
                                Text("For \(alloc.targetLabel): \(Int(alloc.nominalPLN)) PLN (maturity)")
                            }
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                alloc.isSurplus
                                    ? VestTone.amber.color.opacity(0.2)
                                    : (alloc.isEarlyRedemption ? VestTone.violet.color.opacity(0.22) : VestTone.electric.color.opacity(0.2))
                            )
                        )
                        .foregroundStyle(
                            alloc.isSurplus
                                ? VestTone.amber.color
                                : (alloc.isEarlyRedemption ? VestTone.violet.color : VestTone.electric.color)
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - 3. Continuity Stacked Bar Chart (Swift Charts)
private struct ContinuityChartCard: View {
    let data: BondPlannerData
    @Binding var selectedYear: Int?

    private struct StackedBarItem: Identifiable {
        let id: String
        let yearLabel: String
        let year: Int
        let category: String
        let amount: Double
    }

    private var chartItems: [StackedBarItem] {
        data.yearlyContinuitySlots.flatMap { slot in
            [
                StackedBarItem(id: "\(slot.id)_existing", yearLabel: slot.label, year: slot.year, category: "Existing", amount: slot.existingNominalPLN),
                StackedBarItem(id: "\(slot.id)_proposed", yearLabel: slot.label, year: slot.year, category: "Recommended Buy", amount: slot.allocatedNewNominalPLN),
                StackedBarItem(id: "\(slot.id)_gap", yearLabel: slot.label, year: slot.year, category: "Unfunded Gap", amount: slot.unfundedGapNominalPLN)
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Month \(String(format: "%02d", data.market.issueMonth)) Continuity Across Upcoming Years")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Existing nominal holdings vs. recommended new purchases & target cash flow")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            // Legend
            HStack(spacing: 14) {
                LegendDot(color: VestActionColor.positive, label: "Existing")
                LegendDot(color: VestTone.electric.color, label: "Recommended Buy")
                LegendDot(color: VestTone.amber.color.opacity(0.5), label: "Unfunded Gap")
            }

            Chart {
                ForEach(chartItems) { item in
                    BarMark(
                        x: .value("Maturity", item.yearLabel),
                        y: .value("Nominal PLN", item.amount)
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                    .cornerRadius(4)
                }

                if data.settings.targetMonthlyNominal > 0 {
                    RuleMark(y: .value("Target", data.settings.targetMonthlyNominal))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(VestTone.rose.color)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target \(Int(data.settings.targetMonthlyNominal)) PLN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VestTone.rose.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.black.opacity(0.75)))
                        }
                }
            }
            .chartForegroundStyleScale([
                "Existing": VestActionColor.positive,
                "Recommended Buy": VestTone.electric.color,
                "Unfunded Gap": VestTone.amber.color.opacity(0.35)
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.white.opacity(0.08))
                    if let val = value.as(Double.self) {
                        AxisValueLabel {
                            Text(val >= 1000 ? String(format: "%.1fk", val / 1000.0) : "\(Int(val))")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .frame(height: 200)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - 4. Year-by-Year Continuity & Bond Yield Comparison
private struct YearlySlotsComparisonCard: View {
    let data: BondPlannerData
    @Binding var selectedYear: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Year-by-Year Breakdown & Best Bond Picker")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Tap any target maturity date to compare net yields (including early redemption of EDO/COI/TOS)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            ForEach(data.yearlyContinuitySlots) { slot in
                let isExpanded = selectedYear == slot.year
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedYear = isExpanded ? nil : slot.year
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(slot.label)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text("(\(slot.holdingYears)Y)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.5))
                                    if slot.shortfallNominalPLN <= 0 {
                                        Text("✓ Covered")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(VestActionColor.positive.opacity(0.25)))
                                            .foregroundStyle(VestActionColor.positive)
                                    } else if let code = slot.recommendedBondCode {
                                        Text(slot.isEarlyRedemption ? "Best: \(code) (Early Exit)" : "Best: \(code)")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(
                                                    slot.isEarlyRedemption
                                                        ? VestTone.violet.color.opacity(0.25)
                                                        : VestTone.electric.color.opacity(0.22)
                                                )
                                            )
                                            .foregroundStyle(slot.isEarlyRedemption ? VestTone.violet.color : VestTone.electric.color)
                                    }
                                }
                                Text("Held: \(Int(slot.existingNominalPLN)) PLN • Need: \(Int(slot.shortfallNominalPLN)) PLN • Buy: \(Int(slot.allocatedNewNominalPLN)) PLN")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.65))
                            }

                            Spacer()

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        Divider().overlay(Color.white.opacity(0.08))

                        if !slot.heldBonds.isEmpty {
                            Text("Currently Held for \(slot.label): \(slot.heldBonds.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(VestActionColor.positive)
                        }

                        Text("Net Return per 100 PLN Bond After \(slot.holdingYears) Year(s) (19% Tax & Early Exit Fee Included):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))

                        ForEach(Array(slot.alternatives.enumerated()), id: \.element.id) { idx, opt in
                            HStack {
                                HStack(spacing: 6) {
                                    if idx == 0 {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(VestTone.amber.color)
                                    }
                                    Text(opt.bondCode)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                    if opt.isEarlyRedemption {
                                        Text("Early exit at \(slot.holdingYears)Y (-\(String(format: "%.2f", opt.earlyRedemptionFeePerBondPLN)) PLN fee)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(VestTone.violet.color)
                                    } else {
                                        Text("Full \(opt.nativeDurationYears)Y maturity")
                                            .font(.system(size: 10))
                                            .foregroundStyle(VestActionColor.positive)
                                    }
                                }
                                Spacer()
                                Text("+\(String(format: "%.2f", opt.netProfitPerBondPLN)) PLN (\(String(format: "%.2f%%", opt.effectiveAnnualRatePct))/yr)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(idx == 0 ? VestActionColor.positive : .white.opacity(0.7))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

// MARK: - 5. 12-Month x Multi-Year Maturity Heatmap Grid
private struct MaturityHeatmapCard: View {
    let data: BondPlannerData
    @Binding var selectedCellId: String?

    private let monthHeaders = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    private var selectedCell: MonthlyMaturityCell? {
        guard let id = selectedCellId else { return nil }
        for row in data.maturityCalendar {
            if let found = row.months.first(where: { $0.id == id }) {
                return found
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("12-Month × Multi-Year Continuity Matrix")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Month-by-month bond maturity coverage across all 12 calendar months. Tap any month cell for details.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            // Month header row
            HStack(spacing: 4) {
                Text("Year")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 38, alignment: .leading)

                ForEach(0..<12, id: \.self) { mIdx in
                    Text(monthHeaders[mIdx])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(
                            (mIdx + 1) == data.market.issueMonth
                                ? VestTone.electric.color
                                : .white.opacity(0.55)
                        )
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(data.maturityCalendar) { row in
                HStack(spacing: 4) {
                    Text(String(row.year))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 38, alignment: .leading)

                    ForEach(row.months) { cell in
                        let isSelected = cell.id == selectedCellId
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCellId = isSelected ? nil : cell.id
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(cellColor(for: cell))
                                .frame(height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(
                                            isSelected
                                                ? Color.white
                                                : (cell.isCurrentIssueMonth ? VestTone.electric.color.opacity(0.6) : Color.clear),
                                            lineWidth: isSelected ? 1.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Selected Cell Callout
            if let cell = selectedCell {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Maturity Month: \(cell.label)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(cell.coveragePct))% of \(Int(cell.targetNominalPLN)) PLN target")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(cell.coveragePct >= 100 ? VestActionColor.positive : VestTone.amber.color)
                    }

                    Text("Held Nominal: \(Int(cell.existingNominalPLN)) PLN • Proposed Buy: \(Int(cell.proposedNominalPLN)) PLN • Shortfall: \(Int(cell.shortfallNominalPLN)) PLN")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))

                    if !cell.heldBonds.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(cell.heldBonds) { hb in
                                Text("\(hb.code): \(Int(hb.nominalPLN)) PLN")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(VestActionColor.positive.opacity(0.2)))
                                    .foregroundStyle(VestActionColor.positive)
                            }
                        }
                    } else {
                        Text("No bonds currently held with native maturity in \(cell.label).")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }

    private func cellColor(for cell: MonthlyMaturityCell) -> Color {
        if cell.existingNominalPLN >= cell.targetNominalPLN && cell.targetNominalPLN > 0 {
            return VestActionColor.positive.opacity(0.85)
        }
        if (cell.existingNominalPLN + cell.proposedNominalPLN) >= cell.targetNominalPLN && cell.targetNominalPLN > 0 {
            return VestTone.electric.color.opacity(0.8)
        }
        if cell.existingNominalPLN > 0 || cell.proposedNominalPLN > 0 {
            return VestTone.amber.color.opacity(0.75)
        }
        return Color.white.opacity(0.07)
    }
}

// MARK: - 6. Early Termination ("Przedterminowy Wykup") Advisor Card
private struct EarlyRedemptionAdvisorCard: View {
    let recommendations: [EarlyRedemptionRecommendation]
    let targetMonthlyNominal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VestTone.violet.color)
                        Text("PRZEDTERMINOWY WYKUP ADVISOR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(VestTone.violet.color)
                    }
                    Text("Which Held Bonds to Early Terminate")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            Text("If an upcoming month has a cash flow gap, these existing longer-term bonds in your portfolio can be early-redeemed with minimal penalty:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            if recommendations.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VestActionColor.positive)
                    Text("No early redemptions needed for your current target months, or no surplus long-term bonds available to reallocate.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.vertical, 4)
            } else {
                ForEach(recommendations.prefix(6)) { rec in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 6) {
                                Text("For \(rec.targetLabel)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(VestTone.violet.color.opacity(0.25)))
                                    .foregroundStyle(VestTone.violet.color)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text("Redeem \(rec.recommendedRedeemUnits)× \(rec.sourceBondCode)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text("\(Int(rec.recommendedRedeemNominalPLN)) PLN")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(VestActionColor.positive)
                        }

                        Text("\(rec.reason) • Total est. fee: \(String(format: "%.2f", rec.estimatedFeePLN)) PLN")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

// MARK: - 7. Current "List Emisyjny" Reference Card
private struct ListEmisyjnyCard: View {
    let market: BondMarketConditions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Offer (List Emisyjny \(market.issueMonthLabel))")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Live terms scraped from obligacjeskarbowe.pl")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }

            ForEach(market.availableSeries) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(s.code)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            if s.isFamilyBond {
                                Text("800+")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(VestTone.amber.color.opacity(0.25)))
                                    .foregroundStyle(VestTone.amber.color)
                            }
                        }
                        Text(s.name)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("1st yr: \(String(format: "%.2f%%", s.firstYearRatePct))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VestActionColor.positive)
                        let ruleText = s.indexation == "cpi"
                            ? "CPI + \(String(format: "%.2f%%", s.marginPct)) • Fee \(String(format: "%.2f", s.earlyRedemptionFeePLN)) zł"
                            : (s.indexation == "nbp"
                                ? "NBP + \(String(format: "%.2f%%", s.marginPct)) • Fee \(String(format: "%.2f", s.earlyRedemptionFeePLN)) zł"
                                : "Fixed • Fee \(String(format: "%.2f", s.earlyRedemptionFeePLN)) zł")
                        Text(ruleText)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.vertical, 4)
                if s.id != market.availableSeries.last?.id {
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

// MARK: - Settings Sheet
private struct BondPlannerSettingsSheet: View {
    @ObservedObject var viewModel: BondPlannerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Cash Flow & Investment Budget") {
                    HStack {
                        Text("Monthly Target (PLN)")
                        Spacer()
                        TextField("3000", text: $viewModel.draftTargetMonthly)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Available to Invest Now (PLN)")
                        Spacer()
                        TextField("10000", text: $viewModel.draftInvestmentBudget)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    }

                    Stepper("Planning Horizon: \(viewModel.draftHorizonYears) years", value: $viewModel.draftHorizonYears, in: 1...12)

                    Toggle("Include 800+ Family Bonds (ROS/ROD)", isOn: $viewModel.draftIncludeFamilyBonds)
                }

                Section("Macroeconomic Assumptions") {
                    Toggle("Override Live CPI / NBP Rates", isOn: $viewModel.draftUseCustomRates)

                    if viewModel.draftUseCustomRates {
                        HStack {
                            Text("Expected CPI Inflation (%)")
                            Spacer()
                            TextField("2.50", text: $viewModel.draftInflationRate)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Expected NBP Ref Rate (%)")
                            Spacer()
                            TextField("3.75", text: $viewModel.draftNbpRate)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("Bond Ladder Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.saveDraftSettings() }
                    }
                    .disabled(viewModel.isSavingSettings)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

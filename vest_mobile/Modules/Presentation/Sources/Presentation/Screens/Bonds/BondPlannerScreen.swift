import SwiftUI
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

                // 2. Year-by-Year Continuity & Best Bond Comparison
                YearlySlotsComparisonCard(
                    data: data,
                    selectedYear: $selectedContinuityYear
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // 3. 12-Month x Multi-Year Continuity Heatmap Grid
                MaturityHeatmapCard(
                    data: data,
                    selectedCellId: $selectedCalendarCellId
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // 4. Early Termination ("Przedterminowy Wykup") Advisor (Collapsed by default)
                EarlyRedemptionAdvisorCard(
                    recommendations: data.earlyRedemptionRecommendations,
                    targetMonthlyNominal: data.settings.targetMonthlyNominal
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                // 5. Current "List Emisyjny" Reference Table (Collapsed by default)
                ListEmisyjnyCard(market: data.market)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 28)
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

// MARK: - 2. Year-by-Year Continuity & Bond Yield Comparison
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

// MARK: - 3. 12-Month x Multi-Year Maturity Heatmap Grid (Carry-On Model, Δ Display)
private struct CarryTransfer: Identifiable {
    var id: String { "\(monthLabel)_\(Int(amountPLN))" }
    let monthLabel: String
    let amountPLN: Double
}

private struct EffectiveMatrixCell: Identifiable {
    let base: MonthlyMaturityCell
    let carryInNominalPLN: Double
    let carryInSources: [CarryTransfer]
    let carryOutNominalPLN: Double
    let carryOutTargets: [CarryTransfer]
    let unabsorbedSurplusNominalPLN: Double

    var id: String { base.id }

    var directNominalPLN: Double {
        base.existingNominalPLN + base.proposedNominalPLN
    }

    /// Total nominal covering this month's target (direct up to target + carried-in from earlier surplus + any unabsorbed excess)
    var effectiveNominalPLN: Double {
        if directNominalPLN >= base.targetNominalPLN {
            return base.targetNominalPLN + unabsorbedSurplusNominalPLN
        } else {
            return directNominalPLN + carryInNominalPLN
        }
    }

    var effectiveCoverageRatio: Double {
        guard base.targetNominalPLN > 0 else {
            return effectiveNominalPLN > 0 ? 1.0 : 0.0
        }
        return effectiveNominalPLN / base.targetNominalPLN
    }

    var effectiveCoveragePct: Double {
        effectiveCoverageRatio * 100.0
    }

    var effectiveShortfallPLN: Double {
        max(0.0, base.targetNominalPLN - effectiveNominalPLN)
    }

    var isCovered: Bool {
        base.targetNominalPLN > 0 && effectiveNominalPLN >= base.targetNominalPLN - 0.5
    }
}

private struct EffectiveYearlyRow: Identifiable {
    let id: String
    let year: Int
    let cells: [EffectiveMatrixCell]

    var coveredMonthsCount: Int {
        cells.filter(\.isCovered).count
    }
}

private struct MaturityHeatmapCard: View {
    let data: BondPlannerData
    @Binding var selectedCellId: String?

    private let monthHeaders = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    /// Computes chronological surplus spillover across months so e.g. 30k in Jan (with 10k target) covers Jan (10k), Feb (10k), and Mar (10k).
    private var effectiveRows: [EffectiveYearlyRow] {
        let allBaseCells = data.maturityCalendar.flatMap(\.months)
        guard !allBaseCells.isEmpty else { return [] }

        struct SurplusBucket {
            let cellIndex: Int
            let label: String
            var remainingPLN: Double
        }

        var buckets: [SurplusBucket] = []
        var carryInByIdx: [Int: [CarryTransfer]] = [:]
        var carryOutByIdx: [Int: [CarryTransfer]] = [:]
        var initialSurplusByIdx: [Int: Double] = [:]

        for (idx, cell) in allBaseCells.enumerated() {
            let direct = cell.existingNominalPLN + cell.proposedNominalPLN
            let target = cell.targetNominalPLN

            if direct > target + 0.01 {
                let excess = direct - target
                initialSurplusByIdx[idx] = excess
                buckets.append(SurplusBucket(cellIndex: idx, label: cell.label, remainingPLN: excess))
            } else if direct + 0.01 < target {
                var needed = target - direct
                var bIdx = 0
                while needed > 0.01 && bIdx < buckets.count {
                    let avail = buckets[bIdx].remainingPLN
                    if avail > 0.01 {
                        let used = min(avail, needed)
                        buckets[bIdx].remainingPLN -= used
                        needed -= used

                        let srcIdx = buckets[bIdx].cellIndex
                        carryInByIdx[idx, default: []].append(
                            CarryTransfer(monthLabel: buckets[bIdx].label, amountPLN: used)
                        )
                        carryOutByIdx[srcIdx, default: []].append(
                            CarryTransfer(monthLabel: cell.label, amountPLN: used)
                        )
                    }
                    bIdx += 1
                }
            }
        }

        var flatEffective: [String: EffectiveMatrixCell] = [:]
        for (idx, cell) in allBaseCells.enumerated() {
            let inTransfers = carryInByIdx[idx] ?? []
            let outTransfers = carryOutByIdx[idx] ?? []
            let totalIn = inTransfers.reduce(0.0) { $0 + $1.amountPLN }
            let totalOut = outTransfers.reduce(0.0) { $0 + $1.amountPLN }
            let initExcess = initialSurplusByIdx[idx] ?? 0.0
            let unabsorbed = max(0.0, initExcess - totalOut)

            flatEffective[cell.id] = EffectiveMatrixCell(
                base: cell,
                carryInNominalPLN: totalIn,
                carryInSources: inTransfers,
                carryOutNominalPLN: totalOut,
                carryOutTargets: outTransfers,
                unabsorbedSurplusNominalPLN: unabsorbed
            )
        }

        return data.maturityCalendar.map { row in
            EffectiveYearlyRow(
                id: row.id,
                year: row.year,
                cells: row.months.compactMap { flatEffective[$0.id] }
            )
        }
    }

    private var selectedEffectiveCell: EffectiveMatrixCell? {
        guard let id = selectedCellId else { return nil }
        for row in effectiveRows {
            if let found = row.cells.first(where: { $0.id == id }) {
                return found
            }
        }
        return nil
    }

    var body: some View {
        let rows = effectiveRows

        VStack(alignment: .leading, spacing: 14) {
            Text("12-Month × Multi-Year Continuity Matrix")
                .font(.headline)
                .foregroundStyle(.white)

            // Month header row
            HStack(spacing: 4) {
                Text("Year")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, alignment: .leading)

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

            ForEach(rows) { row in
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(row.year))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("\(row.coveredMonthsCount)/12")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                row.coveredMonthsCount == 12
                                    ? VestActionColor.positive
                                    : (row.coveredMonthsCount > 0 ? VestTone.ocean.color : .white.opacity(0.35))
                            )
                    }
                    .frame(width: 44, alignment: .leading)

                    ForEach(row.cells) { eCell in
                        let isSelected = eCell.id == selectedCellId
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCellId = isSelected ? nil : eCell.id
                            }
                        } label: {
                            MatrixCellView(
                                effectiveCell: eCell,
                                isSelected: isSelected
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Selected Cell Callout
            if let eCell = selectedEffectiveCell {
                SelectedMatrixCellDetailView(effectiveCell: eCell)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

private struct MatrixCellView: View {
    let effectiveCell: EffectiveMatrixCell
    let isSelected: Bool

    private var cell: MonthlyMaturityCell { effectiveCell.base }

    private var target: Double {
        max(cell.targetNominalPLN, 1.0)
    }

    private var directNominal: Double {
        effectiveCell.directNominalPLN
    }

    private var carryInNominal: Double {
        effectiveCell.carryInNominalPLN
    }

    private var effectiveNominal: Double {
        effectiveCell.effectiveNominalPLN
    }

    private var existingRatio: Double {
        guard cell.targetNominalPLN > 0 else { return directNominal > 0 ? 1.0 : 0.0 }
        return min(cell.existingNominalPLN, target) / target
    }

    private var directRatio: Double {
        guard cell.targetNominalPLN > 0 else { return directNominal > 0 ? 1.0 : 0.0 }
        return min(directNominal, target) / target
    }

    private var effectiveRatio: Double {
        effectiveCell.effectiveCoverageRatio
    }

    /// Only true when there is still unabsorbed excess beyond target after carrying forward to later months
    private var isUnabsorbedExceeded: Bool {
        cell.targetNominalPLN > 0 && effectiveCell.unabsorbedSurplusNominalPLN > 0.5
    }

    private var isExactOrCarryCovered: Bool {
        cell.targetNominalPLN > 0 && abs(effectiveNominal - cell.targetNominalPLN) <= 0.5
    }

    private var hasCarryIn: Bool {
        carryInNominal > 0.5
    }

    private var hasCarryOut: Bool {
        effectiveCell.carryOutNominalPLN > 0.5
    }

    private var primaryColor: Color {
        if effectiveNominal <= 0 {
            return Color.clear
        }
        if isUnabsorbedExceeded {
            return VestTone.rose.color
        }
        if isExactOrCarryCovered {
            if hasCarryIn && directNominal < cell.targetNominalPLN - 0.5 {
                return VestTone.ocean.color
            }
            if cell.proposedNominalPLN > 0 && cell.existingNominalPLN < cell.targetNominalPLN - 0.5 {
                return VestTone.electric.color
            }
            return VestActionColor.positive
        }
        // Graduated color between 1% and 99% (including partial carry-over!)
        let pct = effectiveRatio * 100.0
        if pct < 40.0 {
            return VestTone.sunset.color
        } else if pct < 75.0 {
            return VestTone.amber.color
        } else {
            return VestTone.sage.color
        }
    }

    private var cellLabelText: String {
        guard effectiveNominal > 0 || directNominal > 0 else { return "—" }
        let diff = effectiveNominal - cell.targetNominalPLN
        if abs(diff) <= 0.5 {
            return hasCarryIn ? "↳✓" : (hasCarryOut ? "✓→" : "✓")
        } else if diff > 0 {
            return "+\(compactPLN(diff))"
        } else {
            return "-\(compactPLN(abs(diff)))"
        }
    }

    private func compactPLN(_ value: Double) -> String {
        if value >= 1000 {
            let k = value / 1000.0
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0fk", k)
                : String(format: "%.1fk", k)
        }
        return "\(Int(round(value)))"
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let clampedExistingFill = CGFloat(min(max(existingRatio, 0.0), 1.0)) * height
            let clampedDirectFill = CGFloat(min(max(directRatio, 0.0), 1.0)) * height
            let clampedEffectiveFill = CGFloat(min(max(effectiveRatio, 0.0), 1.0)) * height

            ZStack(alignment: .bottom) {
                // Empty cell track
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.05))

                if effectiveNominal > 0 {
                    // 1. Total effective fill (including carry-in spillover from earlier months)
                    if hasCarryIn {
                        Rectangle()
                            .fill(
                                (isExactOrCarryCovered ? VestTone.ocean.color : primaryColor)
                                    .opacity(0.75)
                            )
                            .frame(height: clampedEffectiveFill)
                    }

                    // 2. Direct proposed + existing fill
                    if directNominal > 0 {
                        if cell.proposedNominalPLN > 0 && !isUnabsorbedExceeded {
                            Rectangle()
                                .fill(VestTone.electric.color.opacity(0.72))
                                .frame(height: clampedDirectFill)
                            if cell.existingNominalPLN > 0 {
                                Rectangle()
                                    .fill(primaryColor.opacity(0.88))
                                    .frame(height: clampedExistingFill)
                            }
                        } else {
                            Rectangle()
                                .fill(primaryColor.opacity(isUnabsorbedExceeded ? 0.85 : 0.82))
                                .frame(height: hasCarryIn ? clampedDirectFill : clampedEffectiveFill)
                        }
                    }
                }

                // Top accent cap: white/rose when unabsorbed exceeded, or ocean cyan when feeding subsequent months
                if isUnabsorbedExceeded {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.75))
                            .frame(height: 2.5)
                        Spacer(minLength: 0)
                    }
                } else if hasCarryOut {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(VestTone.ocean.color)
                            .frame(height: 2.5)
                        Spacer(minLength: 0)
                    }
                }

                // Centered text label showing closeness / carry-over
                Text(cellLabelText)
                    .font(.system(size: 8.0, weight: .bold, design: .rounded))
                    .foregroundStyle(effectiveNominal > 0 ? Color.white : Color.white.opacity(0.22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.55), radius: 1, x: 0, y: 0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.white
                            : (isUnabsorbedExceeded
                                ? VestTone.rose.color
                                : (hasCarryIn
                                    ? VestTone.ocean.color.opacity(0.65)
                                    : (cell.isCurrentIssueMonth ? VestTone.electric.color.opacity(0.65) : Color.white.opacity(0.06)))),
                        lineWidth: isSelected ? 1.6 : (isUnabsorbedExceeded || cell.isCurrentIssueMonth ? 1.1 : 0.6)
                    )
            )
        }
        .frame(height: 30)
    }
}

private struct SelectedMatrixCellDetailView: View {
    let effectiveCell: EffectiveMatrixCell

    private var cell: MonthlyMaturityCell { effectiveCell.base }

    private var directNominal: Double {
        effectiveCell.directNominalPLN
    }

    private var effectiveNominal: Double {
        effectiveCell.effectiveNominalPLN
    }

    private var isUnabsorbedExceeded: Bool {
        cell.targetNominalPLN > 0 && effectiveCell.unabsorbedSurplusNominalPLN > 0.5
    }

    private var isExactOrCarryCovered: Bool {
        cell.targetNominalPLN > 0 && abs(effectiveNominal - cell.targetNominalPLN) <= 0.5
    }

    private var statusTitle: String {
        if isUnabsorbedExceeded {
            return "Exceeded (+\(Int(round(effectiveCell.unabsorbedSurplusNominalPLN))) PLN unused)"
        } else if isExactOrCarryCovered {
            if effectiveCell.carryInNominalPLN > 0.5 && directNominal < cell.targetNominalPLN - 0.5 {
                return "Covered via Carry-Over (100%)"
            } else if effectiveCell.carryOutNominalPLN > 0.5 {
                return "On Target + Covers +\(effectiveCell.carryOutTargets.count) mo"
            }
            return "On Target (100%)"
        } else if effectiveNominal > 0 {
            return "Shortfall (-\(Int(round(effectiveCell.effectiveShortfallPLN))) PLN • \(Int(round(effectiveCell.effectiveCoveragePct)))%)"
        } else {
            return "Uncovered (0% — needs \(Int(round(cell.targetNominalPLN))) PLN)"
        }
    }

    private var statusColor: Color {
        if isUnabsorbedExceeded {
            return VestTone.rose.color
        } else if isExactOrCarryCovered {
            return effectiveCell.carryInNominalPLN > 0.5 && directNominal < cell.targetNominalPLN - 0.5
                ? VestTone.ocean.color
                : VestActionColor.positive
        } else if effectiveCell.effectiveCoveragePct >= 75 {
            return VestTone.sage.color
        } else if effectiveCell.effectiveCoveragePct >= 40 {
            return VestTone.amber.color
        } else {
            return VestTone.sunset.color
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Maturity Month: \(cell.label)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(statusTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
            }

            // Visual gauge bar showing Held + Proposed + Carry-In vs 100% Target marker
            GeometryReader { geo in
                let maxScale = max(cell.targetNominalPLN * 1.4, directNominal, effectiveNominal, 1.0)
                let targetX = CGFloat(cell.targetNominalPLN / maxScale) * geo.size.width
                let existingW = CGFloat(cell.existingNominalPLN / maxScale) * geo.size.width
                let proposedW = CGFloat(cell.proposedNominalPLN / maxScale) * geo.size.width
                let carryInW = CGFloat(effectiveCell.carryInNominalPLN / maxScale) * geo.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)

                    HStack(spacing: 0) {
                        if existingW > 0 {
                            Rectangle()
                                .fill(isUnabsorbedExceeded ? VestTone.rose.color : VestActionColor.positive)
                                .frame(width: existingW, height: 8)
                        }
                        if proposedW > 0 {
                            Rectangle()
                                .fill(VestTone.electric.color)
                                .frame(width: proposedW, height: 8)
                        }
                        if carryInW > 0 {
                            Rectangle()
                                .fill(VestTone.ocean.color)
                                .frame(width: carryInW, height: 8)
                        }
                    }
                    .clipShape(Capsule())

                    // Target 100% marker line
                    if cell.targetNominalPLN > 0 {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 14)
                            .offset(x: min(max(targetX - 1, 0), geo.size.width - 2))
                    }
                }
            }
            .frame(height: 14)

            HStack {
                Text("Direct Held: \(Int(cell.existingNominalPLN)) PLN • Buy: \(Int(cell.proposedNominalPLN)) PLN • Carry-In: \(Int(effectiveCell.carryInNominalPLN)) PLN")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if effectiveCell.effectiveShortfallPLN > 0 {
                    Text("Missing: \(Int(effectiveCell.effectiveShortfallPLN)) PLN")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(statusColor)
                }
            }

            // Carry-In / Carry-Out breakdown pills
            if !effectiveCell.carryInSources.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(effectiveCell.carryInSources) { src in
                            Text("↳ +\(Int(src.amountPLN)) PLN carried from \(src.monthLabel)")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(VestTone.ocean.color.opacity(0.22)))
                                .foregroundStyle(VestTone.ocean.color)
                        }
                    }
                }
            }

            if !effectiveCell.carryOutTargets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(effectiveCell.carryOutTargets) { dst in
                            Text("→ \(Int(dst.amountPLN)) PLN covers \(dst.monthLabel)")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(VestTone.ocean.color.opacity(0.22)))
                                .foregroundStyle(VestTone.ocean.color)
                        }
                    }
                }
            }

            if !cell.heldBonds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
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
                }
            } else if effectiveCell.carryInNominalPLN <= 0 {
                Text("No bonds maturing in \(cell.label) and no surplus carried over from earlier months.")
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

// MARK: - 4. Early Termination ("Przedterminowy Wykup") Advisor Card (Collapsed by default)
private struct EarlyRedemptionAdvisorCard: View {
    let recommendations: [EarlyRedemptionRecommendation]
    let targetMonthlyNominal: Double

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
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
                    if !recommendations.isEmpty {
                        Text("\(recommendations.count)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(VestTone.violet.color.opacity(0.25)))
                            .foregroundStyle(VestTone.violet.color)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().overlay(Color.white.opacity(0.08))

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
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VestCardBackground())
    }
}

// MARK: - 5. Current "List Emisyjny" Reference Card (Collapsed by default)
private struct ListEmisyjnyCard: View {
    let market: BondMarketConditions

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
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
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().overlay(Color.white.opacity(0.08))

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

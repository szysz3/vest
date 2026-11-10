import Foundation
import Core
import Domain

@MainActor
public final class BondPlannerViewModel: ObservableObject {
    @Published public private(set) var state: ViewState<BondPlannerData, ViewModelError> = .idle
    @Published public var selectedReferenceMonth: Int? = nil
    @Published public var selectedCalendarCellId: String? = nil
    @Published public var selectedContinuityYear: Int? = nil
    @Published public var isShowingSettingsSheet: Bool = false

    // Editable draft settings for the configuration sheet
    @Published public var draftTargetMonthly: String = "3000"
    @Published public var draftInvestmentBudget: String = "10000"
    @Published public var draftHorizonYears: Int = 5
    @Published public var draftIncludeFamilyBonds: Bool = false
    @Published public var draftUseCustomRates: Bool = false
    @Published public var draftInflationRate: String = "2.5"
    @Published public var draftNbpRate: String = "3.75"
    @Published public private(set) var isSavingSettings: Bool = false

    private let getBondPlannerUseCase: GetBondPlannerUseCaseProtocol
    private let updateBondPlannerSettingsUseCase: UpdateBondPlannerSettingsUseCaseProtocol

    public nonisolated init(
        getBondPlannerUseCase: GetBondPlannerUseCaseProtocol,
        updateBondPlannerSettingsUseCase: UpdateBondPlannerSettingsUseCaseProtocol
    ) {
        self.getBondPlannerUseCase = getBondPlannerUseCase
        self.updateBondPlannerSettingsUseCase = updateBondPlannerSettingsUseCase
    }

    public func loadIfNeeded() async {
        guard state.isIdle else { return }
        await load()
    }

    public func load(referenceMonth: Int? = nil) async {
        if state.isIdle {
            state = .loading
        }
        let targetMonth = referenceMonth ?? selectedReferenceMonth
        do {
            let query = BondPlannerQuery(referenceMonth: targetMonth)
            let data = try await getBondPlannerUseCase.execute(query: query)
            syncDrafts(with: data)
            if selectedReferenceMonth == nil {
                selectedReferenceMonth = data.market.issueMonth
            }
            state = .loaded(data)
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }

    public func selectReferenceMonth(_ month: Int) async {
        selectedReferenceMonth = month
        await load(referenceMonth: month)
    }

    public func toggleFamilyBonds(_ enabled: Bool) async {
        guard case .loaded(let current) = state else { return }
        var updated = current.settings
        updated.includeFamilyBonds = enabled
        await applyAndSaveSettings(updated)
    }

    public func selectHorizonYears(_ years: Int) async {
        guard case .loaded(let current) = state else { return }
        var updated = current.settings
        updated.horizonYears = years
        await applyAndSaveSettings(updated)
    }

    public func saveDraftSettings() async {
        let targetVal = Double(draftTargetMonthly.replacingOccurrences(of: ",", with: ".")) ?? 3000.0
        let budgetVal = Double(draftInvestmentBudget.replacingOccurrences(of: ",", with: ".")) ?? 10000.0
        let customCpi: Double? = draftUseCustomRates
            ? Double(draftInflationRate.replacingOccurrences(of: ",", with: "."))
            : nil
        let customNbp: Double? = draftUseCustomRates
            ? Double(draftNbpRate.replacingOccurrences(of: ",", with: "."))
            : nil

        let settings = BondPlannerSettings(
            targetMonthlyNominal: max(0, targetVal),
            horizonYears: draftHorizonYears,
            investmentBudget: max(0, budgetVal),
            includeFamilyBonds: draftIncludeFamilyBonds,
            customInflationRatePct: customCpi,
            customNbpRatePct: customNbp
        )

        isSavingSettings = true
        await applyAndSaveSettings(settings)
        isSavingSettings = false
        isShowingSettingsSheet = false
    }

    private func applyAndSaveSettings(_ settings: BondPlannerSettings) async {
        do {
            _ = try await updateBondPlannerSettingsUseCase.execute(settings)
            let query = BondPlannerQuery(referenceMonth: selectedReferenceMonth)
            let refreshed = try await getBondPlannerUseCase.execute(query: query)
            syncDrafts(with: refreshed)
            state = .loaded(refreshed)
        } catch {
            state = .failed(ViewModelError(from: error))
        }
    }

    private func syncDrafts(with data: BondPlannerData) {
        draftTargetMonthly = String(format: "%.0f", data.settings.targetMonthlyNominal)
        draftInvestmentBudget = String(format: "%.0f", data.settings.investmentBudget)
        draftHorizonYears = data.settings.horizonYears
        draftIncludeFamilyBonds = data.settings.includeFamilyBonds
        let hasCustom = data.settings.customInflationRatePct != nil || data.settings.customNbpRatePct != nil
        draftUseCustomRates = hasCustom
        draftInflationRate = String(format: "%.2f", data.market.effectiveInflationRatePct)
        draftNbpRate = String(format: "%.2f", data.market.effectiveNbpReferenceRatePct)
    }
}

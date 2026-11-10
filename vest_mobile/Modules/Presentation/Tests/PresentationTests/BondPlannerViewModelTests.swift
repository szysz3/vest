import Foundation
import Testing
import Domain
import Core
@testable import Presentation

private final class StubGetBondPlannerUseCase: GetBondPlannerUseCaseProtocol, @unchecked Sendable {
    var result: BondPlannerData?
    var lastQuery: BondPlannerQuery?
    var errorToThrow: Error?

    func execute(query: BondPlannerQuery?) async throws -> BondPlannerData {
        lastQuery = query
        if let err = errorToThrow { throw err }
        guard let res = result else { throw DomainError.unknown("No mock data") }
        return res
    }
}

private final class StubUpdateBondPlannerSettingsUseCase: UpdateBondPlannerSettingsUseCaseProtocol, @unchecked Sendable {
    var lastSettings: BondPlannerSettings?
    var errorToThrow: Error?

    func execute(_ settings: BondPlannerSettings) async throws -> BondPlannerSettings {
        if let err = errorToThrow { throw err }
        lastSettings = settings
        return settings
    }
}

@Suite("BondPlannerViewModel Tests")
@MainActor
struct BondPlannerViewModelTests {
    private func makeSampleData(includeFamily: Bool = false, horizon: Int = 5) -> BondPlannerData {
        let settings = BondPlannerSettings(
            targetMonthlyNominal: 3000.0,
            horizonYears: horizon,
            investmentBudget: 10000.0,
            includeFamilyBonds: includeFamily
        )
        let market = BondMarketConditions(
            referenceDate: "2026-11-10",
            issueMonth: 11,
            issueYear: 2026,
            issueMonthLabel: "11.2026",
            liveInflationRatePct: 2.5,
            liveNbpReferenceRatePct: 3.75,
            effectiveInflationRatePct: 2.5,
            effectiveNbpReferenceRatePct: 3.75,
            sourceUrl: "https://www.obligacjeskarbowe.pl",
            availableSeries: []
        )
        let summary = BondPlannerSummary(
            totalHeldBondsNominalPLN: 14000.0,
            totalHeldBondsActualPLN: 14500.0,
            currentMonthTargetSeriesCount: horizon,
            currentMonthCoveredYearsCount: 3,
            totalRequiredForContinuityPLN: 6000.0,
            budgetAllocatedToContinuityPLN: 6000.0,
            budgetAllocatedToSurplusPLN: 4000.0,
            unfundedContinuityGapPLN: 0.0,
            projectedTotalNetProfitFromBudgetPLN: 1850.0
        )
        return BondPlannerData(
            settings: settings,
            market: market,
            summary: summary,
            yearlyContinuitySlots: [],
            purchaseRecommendations: [],
            earlyRedemptionRecommendations: [],
            maturityCalendar: []
        )
    }

    @Test func loadPopulatesStateAndDrafts() async throws {
        let getStub = StubGetBondPlannerUseCase()
        let updateStub = StubUpdateBondPlannerSettingsUseCase()
        getStub.result = makeSampleData()

        let vm = BondPlannerViewModel(
            getBondPlannerUseCase: getStub,
            updateBondPlannerSettingsUseCase: updateStub
        )

        await vm.load()

        #expect(vm.state.isLoaded)
        #expect(vm.selectedReferenceMonth == 11)
        #expect(vm.draftTargetMonthly == "3000")
        #expect(vm.draftInvestmentBudget == "10000")
        #expect(vm.draftHorizonYears == 5)
    }

    @Test func toggleFamilyBondsAndSaveSettings() async throws {
        let getStub = StubGetBondPlannerUseCase()
        let updateStub = StubUpdateBondPlannerSettingsUseCase()
        getStub.result = makeSampleData(includeFamily: false)

        let vm = BondPlannerViewModel(
            getBondPlannerUseCase: getStub,
            updateBondPlannerSettingsUseCase: updateStub
        )

        await vm.load()
        getStub.result = makeSampleData(includeFamily: true)
        await vm.toggleFamilyBonds(true)

        #expect(updateStub.lastSettings?.includeFamilyBonds == true)
        #expect(vm.state.data?.settings.includeFamilyBonds == true)
    }
}

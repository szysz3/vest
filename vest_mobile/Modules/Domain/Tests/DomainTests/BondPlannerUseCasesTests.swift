import Foundation
import Testing
@testable import Domain

private final class MockBondPlannerRepository: BondPlannerRepository, @unchecked Sendable {
    var plannerResult: BondPlannerData?
    var updatedSettings: BondPlannerSettings?
    var lastQuery: BondPlannerQuery?
    var errorToThrow: Error?

    func fetchBondPlanner(query: BondPlannerQuery?) async throws -> BondPlannerData {
        lastQuery = query
        if let err = errorToThrow { throw err }
        guard let res = plannerResult else { throw DomainError.unknown("No mock data") }
        return res
    }

    func updateBondPlannerSettings(_ settings: BondPlannerSettings) async throws -> BondPlannerSettings {
        if let err = errorToThrow { throw err }
        updatedSettings = settings
        return settings
    }
}

@Suite("Bond Planner Use Cases Tests")
struct BondPlannerUseCasesTests {
    private func makeSampleData() -> BondPlannerData {
        let settings = BondPlannerSettings(
            targetMonthlyNominal: 3000.0,
            horizonYears: 5,
            investmentBudget: 10000.0,
            includeFamilyBonds: false
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
            currentMonthTargetSeriesCount: 5,
            currentMonthCoveredYearsCount: 3,
            totalRequiredForContinuityPLN: 12000.0,
            budgetAllocatedToContinuityPLN: 10000.0,
            budgetAllocatedToSurplusPLN: 0.0,
            unfundedContinuityGapPLN: 2000.0,
            projectedTotalNetProfitFromBudgetPLN: 1250.0
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

    @Test func fetchBondPlannerSuccess() async throws {
        let repo = MockBondPlannerRepository()
        repo.plannerResult = makeSampleData()
        let useCase = GetBondPlannerUseCase(repository: repo)

        let query = BondPlannerQuery(targetMonthly: 3000, referenceMonth: 11)
        let result = try await useCase.execute(query: query)

        #expect(result.settings.targetMonthlyNominal == 3000.0)
        #expect(result.market.issueMonth == 11)
        #expect(repo.lastQuery?.referenceMonth == 11)
    }

    @Test func updateBondPlannerSettingsSuccess() async throws {
        let repo = MockBondPlannerRepository()
        let useCase = UpdateBondPlannerSettingsUseCase(repository: repo)
        let newSettings = BondPlannerSettings(
            targetMonthlyNominal: 4500.0,
            horizonYears: 10,
            investmentBudget: 20000.0,
            includeFamilyBonds: true
        )

        let saved = try await useCase.execute(newSettings)
        #expect(saved.targetMonthlyNominal == 4500.0)
        #expect(saved.includeFamilyBonds == true)
        #expect(repo.updatedSettings == newSettings)
    }
}
